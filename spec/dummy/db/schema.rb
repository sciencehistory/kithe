# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_04_04_144551) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_function :kithe_models_friendlier_id_gen, sql_definition: <<-SQL
      CREATE OR REPLACE FUNCTION public.kithe_models_friendlier_id_gen(min_value bigint, max_value bigint)
       RETURNS text
       LANGUAGE plpgsql
      AS $function$
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
        $function$
  SQL

  create_table "kithe_derivatives", force: :cascade do |t|
    t.string "key", null: false
    t.jsonb "file_data"
    t.uuid "asset_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "key"], name: "index_kithe_derivatives_on_asset_id_and_key", unique: true
    t.index ["asset_id"], name: "index_kithe_derivatives_on_asset_id"
  end

  create_table "kithe_model_contains", id: false, force: :cascade do |t|
    t.uuid "containee_id"
    t.uuid "container_id"
    t.index ["containee_id"], name: "index_kithe_model_contains_on_containee_id"
    t.index ["container_id"], name: "index_kithe_model_contains_on_container_id"
  end

  create_table "kithe_models", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "title", null: false
    t.string "type", null: false
    t.integer "position"
    t.jsonb "json_attributes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "parent_id"
    t.string "friendlier_id", default: -> { "kithe_models_friendlier_id_gen('2821109907456'::bigint, '101559956668415'::bigint)" }, null: false
    t.jsonb "file_data"
    t.uuid "representative_id"
    t.uuid "leaf_representative_id"
    t.integer "kithe_model_type", null: false
    t.index ["friendlier_id"], name: "index_kithe_models_on_friendlier_id", unique: true
    t.index ["leaf_representative_id"], name: "index_kithe_models_on_leaf_representative_id"
    t.index ["parent_id"], name: "index_kithe_models_on_parent_id"
    t.index ["representative_id"], name: "index_kithe_models_on_representative_id"
  end

  add_foreign_key "kithe_derivatives", "kithe_models", column: "asset_id"
  add_foreign_key "kithe_model_contains", "kithe_models", column: "containee_id"
  add_foreign_key "kithe_model_contains", "kithe_models", column: "container_id"
  add_foreign_key "kithe_models", "kithe_models", column: "leaf_representative_id"
  add_foreign_key "kithe_models", "kithe_models", column: "parent_id"
  add_foreign_key "kithe_models", "kithe_models", column: "representative_id"
end
