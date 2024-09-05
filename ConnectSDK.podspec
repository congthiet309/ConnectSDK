Pod::Spec.new do |s|
  s.name         = "ConnectSDK"
  s.version      = "1.6.0"
  s.summary      = "Connect SDK is an open source framework that connects your mobile apps with multiple TV platforms."

  s.description  = <<-DESC
                    Connect SDK is an open source framework that connects your mobile apps with multiple TV platforms. Because most TV platforms support a variety of protocols, Connect SDK integrates and abstracts the discovery and connectivity between all supported protocols.
                   DESC

  s.homepage     = "http://www.connectsdk.com/"
  s.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.author       = { "Connect SDK" => "support@connectsdk.com" }
  s.platform     = :ios, "7.1"
  s.ios.deployment_target = "7.1"
  
  # This is where you point to your repository on GitHub or another source
  s.source       = { :git => "https://github.com/dvt282/Connect-SDK-iOS.git",
                     :tag => s.version }

  s.dependency 'google-cast-sdk', '2.10.4.1'
  s.static_framework = true

  s.xcconfig = {
      "OTHER_LDFLAGS" => "$(inherited) -ObjC"
  }

  s.requires_arc = true
  s.libraries = "z", "icucore"
  
  s.prefix_header_contents = <<-PREFIX
                                  #define CONNECT_SDK_VERSION @"#{s.version}"

                                  // Uncomment this line to enable SDK logging
                                  #define CONNECT_SDK_ENABLE_LOG

                                  #ifndef kConnectSDKWirelessSSIDChanged
                                  #define kConnectSDKWirelessSSIDChanged @"Connect_SDK_Wireless_SSID_Changed"
                                  #endif

                                  #ifdef CONNECT_SDK_ENABLE_LOG
                                      // credit: http://stackoverflow.com/a/969291/2715
                                      #ifdef DEBUG
                                      #   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
                                      #else
                                      #   define DLog(...)
                                      #endif
                                  #else
                                      #   define DLog(...)
                                  #endif
                               PREFIX

  non_arc_files =
    "core/Frameworks/asi-http-request/External/Reachability/*.{h,m}",
    "core/Frameworks/asi-http-request/Classes/*.{h,m}"

  s.subspec 'Core' do |sp|
    sp.source_files  = "ConnectSDKDefaultPlatforms.h", "core/**/*.{h,m}"
    sp.exclude_files = (non_arc_files.dup << "core/ConnectSDK*Tests/**/*")
    sp.private_header_files = "core/**/*_Private.h"
    sp.requires_arc = true

    sp.dependency 'ConnectSDK/no-arc'
  end

  s.subspec 'no-arc' do |sp|
    sp.source_files = non_arc_files
    sp.requires_arc = false
    sp.compiler_flags = '-w'
  end
end