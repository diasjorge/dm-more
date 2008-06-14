require 'rubygems'
gem 'dm-core', '=0.9.1'
require 'dm-core'
require 'extlib'
require 'dm-serializer'
require 'pathname'
require 'net/http'
require 'rexml/document'

# TODO: Abstract XML support out from the protocol
# TODO: Build JSON support
module DataMapper
  module Adapters
    class RestAdapter < AbstractAdapter
      include Extlib
      
      # Creates a new resource in the specified repository.
      def create(repository, resource)
        result = http_post("/#{resource.class.storage_name}.xml", resource.to_xml)
        # TODO: Raise error if cannot reach server
        result.kind_of? Net::HTTPSuccess
        # TODO: We're not using the response to update the DataMapper::Resource with the newly acquired ID!!!
      end
      
      # read_set
      #
      # Examples of query string:
      # A. []
      #    GET /books/
      #
      # B. [[:eql, #<Property:Book:id>, 4200]]
      #    GET /books/4200
      #
      # IN PROGRESS
      # TODO: Need to account for query.conditions (i.e., [[:eql, #<Property:Book:id>, 1]] for books/1)
      def read_set(repository, query)
        resource = query.model.name.downcase
        case query.conditions
        when []
          read_set_all(repository, query, resource)
        else
          read_set_for_condition(repository, query, resource)
        end
      end
      
      def update(repository, resource)
        http_put("/#{resource.class.storage_name}.xml", resource.to_xml)
        # TODO: Raise error if cannot reach server
      end
      
      def delete(repository, resource)
        http_delete("/#{resource.class.storage_name}.xml")
        # TODO: Raise error if cannot reach server
      end
      
    protected
      def read_set_all(repository, query, resource)
        # TODO: how do we know whether the resource we're talking to is singular or plural?
        res = http_get("/#{resource.pluralize}.xml")
        data = res.body
        # puts data
        parse_resources(data, resource, query.model, query.fields)
        # TODO: Raise error if cannot reach server
      end
      
      #    GET /books/4200
      def read_set_for_condition(repository, query, resource)
        if is_single_resource_query? query 
          res = read_set_one(repository, query, resource)
          if res
            puts "---" + res
            puts "=== " + res.inspect
          end
          res
        else
          # More complex conditions
          raise NotImplementedError.new
        end
      end    
    
      # query.conditions like [[:eql, #<Property:Book:id>, 4200]]
      def is_single_resource_query?(query)
        query.conditions.length == 1 && query.conditions.first.first == :eql && query.conditions.first[1].name == :id
      end
      
      def read_set_one(repository, query, resource)
        id = query.conditions.first[2]
        # TODO: Again, we're assuming below that we're dealing with a pluralized resource mapping
        res = http_get("/#{resource.pluralize}/#{id}.xml")
        # KLUGE: Rails returns HTML if it can't find a resource.  A properly RESTful app would return a 404, right?
        return nil if res.is_a? Net::HTTPNotFound || res.content_type == "text/html"
        
        data = res.body
        puts "***" + data
        parse_resource(data, resource, query.model, query.fields)
      end
      
      def http_put(uri, data = nil)
        request { |http| http.put(uri, data) }
      end

      def http_post(uri, data)
        request { |http| http.post(uri, data, {"Content-Type", "application/xml"}) }
      end

      def http_get(uri)
        request { |http| http.get(uri) }
      end

      def http_delete(uri)
        request { |http| http.delete(uri) }
      end

      def request(&block)
        res = nil
        Net::HTTP.start(@uri[:host], @uri[:port].to_i) do |http|
          res = yield(http)
        end
        res
      end  

      def parse_resource(xml, resource_name, dm_model_class, dm_properties)
        doc = REXML::Document::new(xml)
        # TODO: handle singular resource case as well....
        resource = dm_model_class.new
        doc.elements.each do |field_element|
          dm_property = dm_properties.find do |p| 
            # *MUST* use Inflection.underscore on the XML as Rails converts '_' to '-' in the XML
            p.name.to_s == Inflection.underscore(field_element.name.to_s)
          end
          if dm_property
            resource.send("#{Inflection.underscore(dm_property.name)}=", field_element.text) 
          end
        end
        resource || Net::HTTPNotFound.new
      end
      
      def parse_resources(xml, resource_name, dm_model_class, dm_properties)
        doc = REXML::Document::new(xml)
        # # TODO: handle singular resource case as well....
        # array = XPath(doc, "/*[@type='array']")
        # if array
        #   parse_resources()
        # else
          
        doc.elements.collect("#{resource_name.pluralize}/#{resource_name}") do |entity_element|
          resource = dm_model_class.new
          entity_element.elements.each do |field_element|
            dm_property = dm_properties.find do |p| 
              # *MUST* use Inflection.underscore on the XML as Rails converts '_' to '-' in the XML
              p.name.to_s == Inflection.underscore(field_element.name.to_s)
            end
            if dm_property
              resource.send("#{Inflection.underscore(dm_property.name)}=", field_element.text) 
            end
          end
          resource
        end
      end  
    end
  end
end