module QRDA
  module Cat1
    class ProcedureRecommendedImporter < SectionImporter
      def initialize(entry_finder = QRDA::Cat1::EntryFinder.new("./cda:entry/cda:procedure[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.65']"))
        super(entry_finder)
        @id_xpath = './cda:id'
        @code_xpath = "./cda:code"
        @author_datetime_xpath = "./cda:author[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.155']/cda:time"
        @anatomical_location_site_xpath = "./cda:targetSiteCode"
        @reason_xpath = "./cda:entryRelationship[@typeCode='RSON']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.88']/cda:value"
        @rank_xpath = "./cda:entryRelationship/cda:observation[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.166']/cda:value/@value"
        @entry_class = QDM::ProcedureRecommended
      end

      def create_entry(entry_element, nrh = NarrativeReferenceHandler.new)
        procedure_recommended = super
        procedure_recommended.anatomicalLocationSite = code_if_present(entry_element.at_xpath(@anatomical_location_site_xpath))
        procedure_recommended.reason = extract_reason(entry_element)
        entity = extract_entity(entry_element, "./cda:participant[@typeCode='PRF']")
        procedure_recommended.requester.concat(entity) if entity
        procedure_recommended.rank = entry_element.at_xpath(@rank_xpath)&.value&.strip.to_i if entry_element.at_xpath(@rank_xpath)&.value
        procedure_recommended
      end

    end
  end
end