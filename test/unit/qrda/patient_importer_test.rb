require_relative '../../test_helper'
require 'cqm/models'

module QRDA
  module Cat1
    class PatientImporterTest < MiniTest::Test

      DEMOGRAPHICS_COUNT = 4.freeze

      def setup
        @map = {}
        @set = Set.new
        @codes_modifiers = {}
      end

      def test_import_with_single_encounter
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/single_encounter.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)

        encounter = patient.qdmPatient.encounters.first
        # lengthOfStay needs to be calculated as day boundary crossings.  The fixture encounter is 23 hours, but crosses the day boundary.
        assert_equal 1, encounter.lengthOfStay.value

        assert_equal DEMOGRAPHICS_COUNT +  1, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_encounters
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_encounters.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT + 2, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_encounters_same_id_different_codes_same_time
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_encounters_same_id_different_codes_same_time.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT +  2, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_encounters_same_id_same_codes_different_time
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_encounters_same_id_same_codes_different_time.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT +  2, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_encounters_same_id_same_codes_same_time
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_encounters_same_id_same_codes_same_time.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT +  1, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_encounters_same_id_same_two_codes_same_time
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_encounters_same_id_same_two_codes_same_time.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT +  1, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_interventions_with_same_id
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_interventions_with_same_id.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT +  1, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_interventions_with_different_id
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_interventions_with_different_id.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT +  2, patient.qdmPatient.dataElements.length
      end

      def test_import_with_two_data_types_with_same_id
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/two_data_types_with_same_id.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        assert_equal DEMOGRAPHICS_COUNT +  2, patient.qdmPatient.dataElements.length
      end

      def test_import_with_code
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/single_encounter.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        patient, _warnings, codes = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)
        # check for fixture entry's code 99203
        assert codes.include?("99203:2.16.840.1.113883.6.12")
      end

      def test_demographics_import_with_code
        patient = CQM::Patient.new
        doc = Nokogiri::XML(File.read('test/fixtures/qrda/single_encounter.xml'))
        doc.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
        doc.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
        codes = Set.new
        # check demographic codes captured
        importer = Cat1::PatientImporter.instance
        importer.get_demographics(patient, doc, codes)
        assert codes.include?("21112-8:2.16.840.1.113883.6.1"), "Should find birthdate code"
        assert codes.include?("F:2.16.840.1.113883.5.1"), "Should find gender code"
        assert codes.include?("2106-3:2.16.840.1.113883.6.238"), "Should find race code"
        assert codes.include?("2186-5:2.16.840.1.113883.6.238"), "Should find ethnicity code"
      end
    end
  end
end
