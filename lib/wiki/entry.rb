require 'yaml/store'
require 'wiki/extensions'
require 'wiki/config'

module Wiki
  class Entry
    class ConcurrentModificationError < RuntimeError; end

    @@transient_variables = []

    def self.transient(attr)
      @@transient_variables << '@' + attr.to_s
    end

    def self.transient_variables
      @@transient_variables
    end

    def self.store
      @store ||=\
      begin
        FileUtils.mkdir_p File.dirname(Config.store), :mode => 0755
        YAML::Store.new(Config.store)
      end
    end

    attr_reader :version, :name

    def initialize(name)
      @version = 0
      @name = name
    end

    def transaction(&block)
      copy = dup
      block.call(copy)
      copy.save
      instance_variables.each do |name|
        instance_variable_set(name, copy.instance_variable_get(name))
      end
    end

    def save
      Entry.store.transaction(false) do |s|
        bucket = self.class.name
        raise ConcurrentModificationError if version > 0 && (!s[bucket] || s[bucket][name].version > version)
        @version += 1
        s[bucket] ||= {}
        s[bucket][name] = self
      end
      self
    end

    def remove
      Entry.store.transaction(false) do |s|
        bucket = self.class.name
        raise ConcurrentModificationError if !s[bucket] || s[bucket][name].version > version
        s[bucket].delete(name)
        s.delete(bucket) if s[bucket].empty?
      end
      @version = 0
      self
    end

    def self.find(name)
      Entry.store.transaction(true) do |s|
        return s[self.name] ? s[self.name][name] : nil
      end
    end

    def to_yaml_properties
      super.reject {|attr| self.class.transient_variables.include?(attr)}
    end
  end
end
