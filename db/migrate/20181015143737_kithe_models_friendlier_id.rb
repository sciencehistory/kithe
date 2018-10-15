class KitheModelsFriendlierId < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      dir.up do
        # Create a function to generate random non-conflicting (with db check) friendlier ids, that
        # look kind of like noids -- 7 chars, 0-9a-z. Min and Max are bigint equivalents that
        # we'll base-36 encode as chars.
        execute <<~'EOSQL'
          CREATE OR REPLACE FUNCTION kithe_models_friendlier_id_gen(min_value bigint, max_value bigint) RETURNS text AS $$
            DECLARE
              new_id_int bigint;
              new_id_str character varying := '';
              done bool;
              tries integer;
              alphabet char[] := ARRAY['0','1','2','3','4','5','6','7','8','9',
                'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
                'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'];
              alphabet_length integer := array_length(alphabet, 1);

            BEGIN
              done := false;
              tries := 0;
              WHILE (NOT done) LOOP
                tries := tries + 1;
                IF (tries > 3) THEN
                  RAISE 'Could not find non-conflicting friendlier_id in 3 tries';
                END IF;

                new_id_int := trunc(random() * (max_value - min_value) + min_value);

                -- convert bigint to a Base-36 alphanumeric string
                -- see https://web.archive.org/web/20130420084605/http://www.jamiebegin.com/base36-conversion-in-postgresql/
                -- https://gist.github.com/btbytes/7159902
                WHILE new_id_int != 0 LOOP
                  new_id_str := alphabet[(new_id_int % alphabet_length)+1] || new_id_str;
                  new_id_int := new_id_int / alphabet_length;
                END LOOP;

                done := NOT exists(SELECT 1 FROM kithe_models WHERE friendlier_id=new_id_str);
              END LOOP;
              RETURN new_id_str;
            END;
            $$ LANGUAGE plpgsql;
        EOSQL

        # min 2176782336 ('1000000') to max 78364164095 ('zzzzzzz') with our 36 char encoding alphabet.
        # 76 billion possible values will hopefully be enough to not run into collisions, if it is not, increase
        # number of chars and/or alphabet to increase keyspace.
        add_column :kithe_models, :friendlier_id, :string, null: false, unique: true, default: -> {'kithe_models_friendlier_id_gen(2176782336, 78364164095)'}
        add_index :kithe_models, :friendlier_id, unique: true
      end

      dir.down do
        remove_index :kithe_models, :friendlier_id
        remove_column :kithe_models, :friendlier_id
        execute "DROP FUNCTION IF EXISTS kithe_models_friendlier_id_gen(bigint, bigint);"
      end
    end
  end
end
