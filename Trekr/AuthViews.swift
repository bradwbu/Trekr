import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "map.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 50)
                
                Text("Trekr")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your journeys")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 30)
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if let error = authManager.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        authManager.signIn(email: email, password: password)
                    }) {
                        Text("Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(authManager.isLoading)
                    
                    Button(action: {
                        showingSignUp = true
                    }) {
                        Text("Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var validationError: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                
                Section(header: Text("Security")) {
                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                }
                
                if let error = validationError ?? authManager.error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Section {
                    Button(action: {
                        if validateForm() {
                            authManager.signUp(name: name, email: email, password: password)
                            if authManager.isAuthenticated {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }) {
                        Text("Create Account")
                    }
                    .disabled(authManager.isLoading)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func validateForm() -> Bool {
        if name.isEmpty {
            validationError = "Please enter your name"
            return false
        }
        
        if email.isEmpty {
            validationError = "Please enter your email"
            return false
        }
        
        if password.isEmpty {
            validationError = "Please enter a password"
            return false
        }
        
        if password != confirmPassword {
            validationError = "Passwords do not match"
            return false
        }
        
        validationError = nil
        return true
    }
}

struct AuthViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView()
                .environmentObject(AuthManager())
            
            SignUpView()
                .environmentObject(AuthManager())
        }
    }
}