module QRDA
  module Cat1
    class DeviceOrderImporter < SectionImporter
      def initialize(entry_finder = QRDA::Cat1::EntryFinder.new("./cda:entry/cda:act[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.130']"))
        super(entry_finder)
        @id_xpath = "./cda:entryRelationship/cda:supply[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.9']/cda:id"
        @code_xpath = "./cda:entryRelationship/cda:supply[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.9']/cda:participant/cda:participantRole/cda:playingDevice/cda:code"
        @author_datetime_xpath = "./cda:entryRelationship/cda:supply[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.9']/cda:author[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.155']/cda:time"
        @reason_xpath = "./cda:entryRelationship/cda:supply[cda:templateId/@root = '2.16.840.1.113883.10.20.24.3.9']/cda:entryRelationship[@typeCode='RSON']/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.24.3.88']/cda:value"
        @entry_class = QDM::DeviceOrder
      end

      def create_entry(entry_element, nrh = NarrativeReferenceHandler.new)
        device_order = super
        entity = extract_entity(entry_element, "./cda:entryRelationship/cda:supply//cda:participant[@typeCode='PRF']")
        device_order.requester.concat(entity) if entity
        device_order.reason = extract_reason(entry_element)
        device_order
      end

    end
  end
end