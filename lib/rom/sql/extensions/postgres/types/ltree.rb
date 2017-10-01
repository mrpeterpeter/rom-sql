module ROM
  module SQL
    module Postgres
      module Values
        LabelPath = ::Struct.new(:path) do
          def labels
            path.split('.')
          end
        end
      end

      # @api public
      module Types
        # @see https://www.postgresql.org/docs/current/static/ltree.html

        LTree = SQL::Types.define(Values::LabelPath) do
          input do |label_path|
            label_path
          end

          output do |label_path|
            Values::LabelPath.new(label_path.to_s)
          end
        end

        module Helpers
          ASCENDANT = ["(".freeze, " @> ".freeze, ")".freeze].freeze
          DESCENDANT = ["(".freeze, " <@ ".freeze, ")".freeze].freeze
          MATCH_LTEXTQUERY = ["(".freeze, " @ ".freeze, ")".freeze].freeze
          module_function
          def custom_sql_expr(string, expr, query)
            Sequel::SQL::PlaceholderLiteralString.new(string, [expr, query])
          end
        end

        TypeExtensions.register(LTree) do
          def match(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: Sequel::SQL::BooleanExpression.new(:'~', expr, query))
          end

          def match_ltextquery(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: Helpers.custom_sql_expr(Helpers::MATCH_LTEXTQUERY, expr, query))
          end

          def descendant(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: Helpers.custom_sql_expr(Helpers::DESCENDANT, expr, query))
          end

          def ascendant(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: Helpers.custom_sql_expr(Helpers::ASCENDANT, expr, query))
          end

          def +(type, expr, other)
            other_value = case other
                          when Values::LabelPath
                            other
                          else
                            Values::LabelPath.new(other)
                          end
            Attribute[LTree].meta(sql_expr: Sequel::SQL::StringExpression.new(:'||', expr, other_value.path))
          end
        end
      end
    end
  end
end
