default_platform(:ios)

platform :ios do
  desc "Build and upload the main branch to TestFlight"

  lane :beta do
    api_key = app_store_connect_api_key(
      key_id: ENV["ASC_KEY_ID"],
      issuer_id: ENV["ASC_ISSUER_ID"],
      key_content: ENV["ASC_KEY_CONTENT_BASE64"],
      is_key_content_base64: true,
      duration: 1200,
      in_house: false
    )

    increment_build_number(
      xcodeproj: "GameClassification.xcodeproj",
      build_number: ENV.fetch("GITHUB_RUN_NUMBER")
    )

    build_app(
      project: "GameClassification.xcodeproj",
      scheme: "GameClassification",
      configuration: "Release",
      clean: true,
      export_method: "app-store",
      output_directory: "build",
      output_name: "GameClassification.ipa",
      export_options: {
        signingStyle: "automatic",
        teamID: ENV["APPLE_TEAM_ID"]
      }
    )

    upload_to_testflight(
      api_key: api_key,
      app_identifier: "com.academy.hendraaaa.GameClassification",
      apple_id: ENV["APP_STORE_APP_ID"],
      ipa: "build/GameClassification.ipa",
      skip_waiting_for_build_processing: true
    )
  end
end