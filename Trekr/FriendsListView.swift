import SwiftUI

struct FriendsListView: View {
    @EnvironmentObject private var locationSharingManager: LocationSharingManager
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var showingAddFriend = false
    @State private var newFriendEmail = ""
    
    var body: some View {
        List {
            Section(header: Text("Friends")) {
                ForEach(locationSharingManager.sharedLocations) { friend in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(String(friend.name.prefix(1)))
                                    .foregroundColor(.white)
                                    .font(.headline)
                            )
                        
                        VStack(alignment: .leading) {
                            Text(friend.name)
                                .font(.headline)
                            Text("Last updated: \(timeAgo(from: friend.lastUpdated))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            locationSharingManager.stopSharingWith(userId: friend.id)
                        }) {
                            Image(systemName: "person.badge.minus")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button(action: {
                    showingAddFriend = true
                }) {
                    Label("Add Friend", systemImage: "person.badge.plus")
                }
            }
        }
        .navigationTitle("Friends")
        .sheet(isPresented: $showingAddFriend) {
            AddFriendView(isPresented: $showingAddFriend)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct AddFriendView: View {
    @EnvironmentObject private var locationSharingManager: LocationSharingManager
    @Binding var isPresented: Bool
    
    @State private var email = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Friend")) {
                    TextField("Email Address", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button("Send Invitation") {
                        if email.isEmpty {
                            errorMessage = "Please enter an email address"
                        } else {
                            // In a real app, we would send an invitation to this email
                            // For demo purposes, we'll just print a message
                            print("Sending invitation to \(email)")
                            isPresented = false
                        }
                    }
                    .disabled(email.isEmpty)
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}

struct FriendsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FriendsListView()
                .environmentObject(LocationSharingManager())
                .environmentObject(AuthManager())
        }
    }
}