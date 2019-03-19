module Kithe
  class Indexer
    # A traject indexer macro that provides an indexing macro to extract values
    # from ruby objects (such as ActiveRecord models, although it does not need to be).
    #
    # You supply a list of method names, which will be called in turn on the source
    # object and previous results. Each result can be a single object or an array of objects.
    # results are always "collected" when there are multiple results.
    #
    # For instance, if you have something that looks like this:
    #
    #    my_obj.authors = [ Author.new(first: "joe", last: "smith"), Author.new(first: "mary", last: "jones")]
    #
    # You index as:
    #
    #     to_field, "author_first", obj_extract("authors", "first")
    #
    # And get `["joe", "mary"]` indexed.  Method chains "short circuit" safely on nil, so if the
    # source object has a nil `authors`, no error will be raised, and you'll simply have no extracted
    # values as expected.
    #
    # In addition to method calls, if an extracted object in the chain is a Hash, a path key given
    # can be a hash key.
    #
    # For instance, if you had an object such that you could access something like:
    #    source_record.authors.collect(&:name_hash).collect { |hash| hash["first"] }
    #
    # You could have a traject indexing file that might look like:
    #
    #     to_field("author_first"), obj_dig("authors", "name", "first")
    #
    # If your path lookup does not end in strings, you may have non-string objects in the traject
    # accumulator. Since most writers at the end of the traject chain expect strings, you may want
    # to use subsequent transformation steps to transform those objects into strings with custom logic.
    #
    # FUTURE: Should we extract this to traject itself?  Not sure if we'll end up putting kithe-tied func
    # in here, or how generalizable it is.
    module ObjExtract
      def obj_extract(*path)
        proc do |record, accumulator, context|
          accumulator.concat Array(Kithe::Indexer::ObjExtract.obj_extractor(record, path))
        end
      end

      def self.obj_extractor(obj, path)
        first, *rest = *path

        result = if obj.kind_of?(Array)
          obj.flat_map {|item| obj_extractor(item, path)}
        elsif obj.kind_of?(Hash)
          obj[first]
        else
          obj.send(first)
        end

        if result.nil? || rest.empty?
          result
        else
          # recurse
          obj_extractor(result, rest)
        end
      end
    end
  end
end
