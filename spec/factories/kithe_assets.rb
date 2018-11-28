FactoryBot.define do
  factory :kithe_asset, class: 'Kithe::Asset' do
    title { "Some Asset" }

    trait :with_file do
      transient do
        file_object { File.open(Kithe::Engine.root.join("spec/test_support/images/1x1_pixel.jpg")) }
      end
      file { file_object }
    end
  end
end
