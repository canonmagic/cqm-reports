module QRDA
  module Cat1
    # This class is the central location for taking a QRDA Cat 1 XML document and converting it
    # into the processed form we store in MongoDB. The class does this by running each measure
    # independently on the XML document
    #
    # This class is a Singleton. It should be accessed by calling PatientImporter.instance
    class PatientImporter
      include Singleton
      include DemographicsImporter

      def initialize
        # This differs from other HDS patient importers in that sections can have multiple importers
        @data_element_importers = []
        @data_element_importers << AdverseEventImporter.new
        @data_element_importers << AllergyIntoleranceImporter.new
        @data_element_importers << AssessmentOrderImporter.new
        @data_element_importers << AssessmentPerformedImporter.new
        @data_element_importers << AssessmentRecommendedImporter.new
        @data_element_importers << CommunicationPerformedImporter.new
        @data_element_importers << DeviceOrderImporter.new
        @data_element_importers << DeviceRecommendedImporter.new
        @data_element_importers << DiagnosisImporter.new
        @data_element_importers << DiagnosticStudyOrderImporter.new
        @data_element_importers << DiagnosticStudyPerformedImporter.new
        @data_element_importers << DiagnosticStudyRecommendedImporter.new
        @data_element_importers << EncounterOrderImporter.new
        @data_element_importers << EncounterRecommendedImporter.new
        @data_element_importers << FamilyHistoryImporter.new
        @data_element_importers << ImmunizationAdministeredImporter.new
        @data_element_importers << ImmunizationOrderImporter.new
        @data_element_importers << InterventionOrderImporter.new
        @data_element_importers << InterventionPerformedImporter.new
        @data_element_importers << InterventionRecommendedImporter.new
        @data_element_importers << LaboratoryTestOrderImporter.new
        @data_element_importers << LaboratoryTestPerformedImporter.new
        @data_element_importers << LaboratoryTestRecommendedImporter.new
        @data_element_importers << MedicationActiveImporter.new
        @data_element_importers << MedicationAdministeredImporter.new
        @data_element_importers << MedicationDispensedImporter.new
        @data_element_importers << MedicationOrderImporter.new
        @data_element_importers << PatientCareExperienceImporter.new
        @data_element_importers << PatientCharacteristicClinicalTrialParticipantImporter.new
        @data_element_importers << PatientCharacteristicExpiredImporter.new
        @data_element_importers << PatientCharacteristicPayerImporter.new
        @data_element_importers << PhysicalExamOrderImporter.new
        @data_element_importers << PhysicalExamPerformedImporter.new
        @data_element_importers << PhysicalExamRecommendedImporter.new
        @data_element_importers << ProcedureOrderImporter.new
        @data_element_importers << ProcedurePerformedImporter.new
        @data_element_importers << ProcedureRecommendedImporter.new
        @data_element_importers << ProgramParticipationImporter.new
        @data_element_importers << ProviderCareExperienceImporter.new
        @data_element_importers << RelatedPersonImporter.new
        @data_element_importers << SubstanceAdministeredImporter.new
        @data_element_importers << SubstanceOrderImporter.new
        @data_element_importers << SubstanceRecommendedImporter.new
        @data_element_importers << SymptomImporter.new
      end 

      def parse_cat1(doc)
        add_conditional_importers(doc)
        patient = Patient.new
        warnings = []
        codes = Set.new
        codes_modifiers = {}
        entry_id_map = {}
        import_data_elements(patient, doc, entry_id_map, codes, codes_modifiers, warnings)
        normalize_references(patient, entry_id_map, warnings)
        get_demographics(patient, doc, codes)
        remove_conditional_importers(doc)
        [patient, warnings, codes, codes_modifiers]
      end

      def import_data_elements(patient, doc, entry_id_map, codes = Set.new, codes_modifiers = {}, warnings = [])
        context = doc.xpath("/cda:ClinicalDocument/cda:component/cda:structuredBody/cda:component/cda:section[cda:templateId/@root = '2.16.840.1.113883.10.20.24.2.1']")
        nrh = NarrativeReferenceHandler.new
        nrh.build_id_map(doc)
        @data_element_importers.each do |importer|
          data_elements, id_map = importer.create_entries(context, nrh)
          new_data_elements = []

          id_map.each_pair do |key, elem_ids|
            split_id = key.split('***')
            id_string = "#{split_id[1]}(root), #{split_id[0]}(extension)"
            warnings << ValidationError.new(message: "Two or more entries share the Id: #{id_string}.") if elem_ids.length > 1
            elem_id = elem_ids.last
            data_element = data_elements.find { |de| de.id == elem_id }

            # If a data_element isn't returned, there was an issue parsing the template, provide a warning
            if data_element.nil?
              warnings << ValidationError.new(message: "Error parsing template with Id: #{id_string}.")
              next
            end

            # Keep the first element with a shared ID
            new_data_elements << data_element

            # Encounters require elements beyond id for uniqueness
            next unless data_element._type == 'QDM::EncounterPerformed'
            unique_element_keys = []
            # Add key_elements_for_determining_encounter_uniqueness to array, this is used to determine if other
            # elements with the same ID should be considered as unique
            unique_element_keys << key_elements_for_determining_encounter_uniqueness(data_element)

            # Loop through all other data elements with the same id
            elem_ids[0,elem_ids.length - 1].each do |dup_id|
              dup_element = data_elements.find { |de| de.id == dup_id }
              dup_element_keys = key_elements_for_determining_encounter_uniqueness(dup_element)
              # See if a previously selected data element shared all of the keys files
              # If all key fields match, move on.
              next if unique_element_keys.include?(dup_element_keys)
              # If all key fields don't match, keep element
              new_data_elements << dup_element
              # Add to list of unique element keys
              unique_element_keys << dup_element_keys
            end
          end

          patient.qdmPatient.dataElements << new_data_elements
          entry_id_map.merge!(id_map)
          warnings.concat(importer.warnings)
          codes.merge(importer.codes)
          codes_modifiers.merge!(importer.codes_modifiers)
          # reset warnings and codes after they're captured so that the importer can be re-used
          importer.warnings = []
          importer.codes_modifiers = {}
          importer.codes = Set.new
        end
      end

      def key_elements_for_determining_encounter_uniqueness(encounter)
        codes = encounter.codes.collect { |dec| "#{dec.code}_#{dec.system}" }.sort.to_s
        admission_date_time = encounter&.relevantPeriod&.low.to_s
        discharge_date_time = encounter&.relevantPeriod&.high.to_s
        "#{codes}#{admission_date_time}#{discharge_date_time}"
      end

      def get_patient_expired(record, doc)
        entry_elements = doc.xpath("/cda:ClinicalDocument/cda:component/cda:structuredBody/cda:component/cda:section[cda:templateId/@root = '2.16.840.1.113883.10.20.24.2.1']/cda:entry/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.54']")
        return unless entry_elements.empty?

        record.expired = true
        record.deathdate = DateTime.parse(entry_elements.at_xpath("./cda:effectiveTime/cda:low")['value']).to_i
      end

      def add_conditional_importers(doc)
        if doc.at_xpath('/cda:ClinicalDocument/cda:templateId[@root="2.16.840.1.113883.10.20.24.1.2" and @extension="2021-08-01"]').nil?
          # For imports prior to R53
          @data_element_importers << DeviceAppliedR52Importer.new
          @data_element_importers << EncounterPerformedR52Importer.new
          @data_element_importers << MedicationDischargeR52Importer.new
        else
          @data_element_importers << EncounterPerformedImporter.new
          @data_element_importers << MedicationDischargeImporter.new
        end
      end

      def remove_conditional_importers(doc)
        if doc.at_xpath('/cda:ClinicalDocument/cda:templateId[@root="2.16.840.1.113883.10.20.24.1.2" and @extension="2021-08-01"]').nil?
          # For imports prior to R53
          @data_element_importers.delete_if { |dei| dei.is_a?(QRDA::Cat1::DeviceAppliedR52Importer) }
          @data_element_importers.delete_if { |dei| dei.is_a?(QRDA::Cat1::EncounterPerformedR52Importer) }
          @data_element_importers.delete_if { |dei| dei.is_a?(QRDA::Cat1::MedicationDischargeR52Importer) }
        else
          @data_element_importers.delete_if { |dei| dei.is_a?(QRDA::Cat1::EncounterPerformedImporter) }
          @data_element_importers.delete_if { |dei| dei.is_a?(QRDA::Cat1::MedicationDischargeImporter) }
        end
      end

      def normalize_references(patient, entry_id_map, warnings)
        patient.qdmPatient.dataElements.each do |data_element|
          next unless data_element.respond_to?(:relatedTo) && data_element.relatedTo

          relations_to_add = []
          data_element.relatedTo.each do |related_to|
            relation_to_add = entry_id_map["#{related_to['value']}***#{related_to['namingSystem']}"]
            # Add the relation if it can be found, otherwise return a warning
            relations_to_add += relation_to_add unless relation_to_add.nil?
            if relation_to_add.nil?
              id_warning_str = "Related To Id: #{related_to['namingSystem']}(root), #{related_to['value']}(extension) cannot be found in QRDA file."
              warnings << ValidationError.new(message: id_warning_str)
            end
          end
          data_element.relatedTo = relations_to_add.map(&:to_s)
        end
      end
    end
  end
end
