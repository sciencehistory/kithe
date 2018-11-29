FactoryBot.define do
  factory :kithe_asset, class: 'Kithe::Asset' do
    title { "Some Asset" }

    trait :with_file do
      transient do
        file_object { File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg")) }
      end
      file { file_object }
    end

    trait :with_faked_metadata do
      with_file

      transient do
        faked_metadata { {} }
      end

      after(:build) do |model, evaluator|
        if evaluator.faked_metadata
          model.file.metadata.merge!(evaluator.faked_metadata.stringify_keys)
        end
      end
    end
  end
end
