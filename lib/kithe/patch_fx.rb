# fx is a gem that lets Rails schema.rb capture postgres functions and triggers
#
# For it to work for our use case, we need it to define functions BEFORE tables when
# doing a `rake db:schema:load`, so we can refer to functions as default values in our
# tables.
#
# This is a known issue in fx, with a PR, but isn't yet merged/released, so we hack
# in a patch to force it. Better than forking.
#
# Based on: https://github.com/teoljungberg/fx/pull/53/

require 'fx/schema_dumper/function'

module Fx
  module SchemaDumper
    module Function
      def tables(stream)
        functions(stream)
        super
      end
    end
  end
end

