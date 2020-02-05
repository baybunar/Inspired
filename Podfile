# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

def common_pods

  pod 'Firebase/Core'
  pod 'Firebase/Database'
  pod 'Firebase/Auth'
  pod 'Firebase/Storage'
  
end

target 'Inspired' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  
  common_pods
  pod 'Koloda'
  pod 'MBProgressHUD'
  pod 'FirebaseUI'
  pod 'FBSDKCoreKit'
  pod 'FBSDKLoginKit'
  pod 'FBSDKShareKit'
  pod 'GoogleSignIn'
  pod 'Kingfisher'
  
  target 'InspiredTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'InspiredUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'InspiredShare' do
  use_frameworks!
  
  common_pods

end
