import SwiftUI
import AppKit

struct DashboardPromotionsSection: View {
    let licenseState: LicenseViewModel.LicenseState
    @State private var isDismissed = false

    var body: some View {
        Group {
            if !isDismissed {
                donationBlock
            }
        }
    }
    
    private var donationBlock: some View {
        VStack(spacing: 16) {
            HStack {
                Text("☕")
                    .font(.system(size: 28))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Support This Tool")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("If you find this tool helpful, consider making a small donation to support its development.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isDismissed = true
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            
            Button(action: {
                openDonationLink()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                    Text("Make a Donation")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(#colorLiteral(red: 0.58, green: 0.19, blue: 0.81, alpha: 1)), Color(#colorLiteral(red: 0.91, green: 0.33, blue: 0.24, alpha: 1))],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
        )
    }
    
    private func openDonationLink() {
        // Replace with your actual donation URL
        if let url = URL(string: "https://www.buymeacoffee.com") {
            NSWorkspace.shared.open(url)
        }
    }
}
