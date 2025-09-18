import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var locationSharingManager: LocationSharingManager
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var isEditingProfile = false
    @State private var showingFriendsList = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    if let user = authManager.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if isEditingProfile {
                        TextField("Name", text: $name)
                        TextField("Email", text: $email)
                        
                        Button("Save Changes") {
                            authManager.updateProfile(name: name, email: email)
                            isEditingProfile = false
                        }
                    } else {
                        Button("Edit Profile") {
                            if let user = authManager.currentUser {
                                name = user.name
                                email = user.email
                            }
                            isEditingProfile = true
                        }
                    }
                }
                
                Section(header: Text("Location Sharing")) {
                    Toggle("Share My Location", isOn: $locationSharingManager.isSharing)
                        .onChange(of: locationSharingManager.isSharing) { isSharing in
                            if isSharing {
                                locationSharingManager.startSharing()
                            } else {
                                locationSharingManager.stopSharing()
                            }
                        }
                    
                    NavigationLink(destination: FriendsListView()) {
                        Text("Manage Friends")
                    }
                }
                
                Section {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView()
            .environmentObject(AuthManager())
            .environmentObject(LocationSharingManager())
    }
}