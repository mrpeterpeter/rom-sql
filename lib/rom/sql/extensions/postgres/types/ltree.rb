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

        TypeExtensions.register(LTree) do
          def match(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: Sequel::SQL::BooleanExpression.new(:'~', expr, query))
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
