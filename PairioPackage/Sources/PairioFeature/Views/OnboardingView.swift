// OnboardingView.swift
// Delightful onboarding flow for first-time users

import SwiftUI
import AppKit

/// Onboarding view shown on first launch
public struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var appeared = false
    @State private var iconBounce = false
    @State private var showConfetti = false
    @Binding var isOnboardingComplete: Bool

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "airpods",
            title: "Welcome to Pairio",
            subtitle: "Audio sharing, reimagined",
            description: "Share your Mac's audio with multiple AirPods simultaneously — movie nights just got better.",
            gradient: [Color(red: 0.4, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.6, blue: 0.5)]
        ),
        OnboardingPage(
            icon: "hand.tap.fill",
            title: "Select & Connect",
            subtitle: "It's super easy",
            description: "Just pick two or more devices from your list and tap to select them. That's it!",
            gradient: [Color(red: 0.5, green: 0.6, blue: 0.9), Color(red: 0.3, green: 0.4, blue: 0.8)]
        ),
        OnboardingPage(
            icon: "waveform.circle.fill",
            title: "Share the Vibes",
            subtitle: "Perfectly synchronized",
            description: "Hit play and enjoy crystal-clear audio across all your devices with zero lag.",
            gradient: [Color(red: 0.8, green: 0.5, blue: 0.7), Color(red: 0.6, green: 0.3, blue: 0.6)]
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "You're All Set!",
            subtitle: "Find me in your menu bar",
            description: "Pairio lives in your menu bar, always ready when you need it. Enjoy! 🎉",
            gradient: [Color(red: 0.9, green: 0.6, blue: 0.3), Color(red: 0.8, green: 0.4, blue: 0.4)]
        )
    ]

    public init(isOnboardingComplete: Binding<Bool>) {
        self._isOnboardingComplete = isOnboardingComplete
    }

    public var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground(colors: pages[currentPage].gradient)
                .ignoresSafeArea()

            // Floating particles
            FloatingParticles()
                .opacity(0.6)

            // Confetti on last page
            if showConfetti {
                ConfettiView()
            }

            VStack(spacing: 0) {
                Spacer()

                // Icon with animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)

                    // Icon circle
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

                    Image(systemName: pages[currentPage].icon)
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                }
                .scaleEffect(iconBounce ? 1.1 : 1.0)
                .offset(y: iconBounce ? -5 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: iconBounce)
                .padding(.bottom, 30)

                // Title
                Text(pages[currentPage].title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

                // Subtitle
                Text(pages[currentPage].subtitle)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 4)

                // Description
                Text(pages[currentPage].description)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
                    .padding(.top, 16)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Page dots
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? .white : .white.opacity(0.4))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.5)) {
                                    currentPage = index
                                    triggerBounce()
                                }
                            }
                    }
                }
                .padding(.bottom, 30)

                // Navigation
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button {
                            withAnimation(.spring(response: 0.5)) {
                                currentPage -= 1
                                triggerBounce()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.5)) {
                                currentPage += 1
                                triggerBounce()
                                if currentPage == pages.count - 1 {
                                    showConfetti = true
                                }
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        HStack {
                            Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                            Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "arrow.right")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(pages[currentPage].gradient[0])
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(currentPage == pages.count - 1 ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: currentPage)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .frame(width: 550, height: 500)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
            triggerBounce()
        }
        .onChange(of: currentPage) { _, _ in
            triggerBounce()
        }
    }

    private func triggerBounce() {
        iconBounce = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            iconBounce = false
        }
    }

    private func completeOnboarding() {
        withAnimation(.spring(response: 0.4)) {
            appeared = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isOnboardingComplete = true
            NSApplication.shared.windows.first { $0.title == "Welcome to Pairio" }?.close()

            let prefs = PreferencesService()
            if !prefs.showInDock {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let gradient: [Color]
}

// MARK: - Animated Gradient Background

private struct AnimatedGradientBackground: View {
    let colors: [Color]
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: colors + colors.reversed(),
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Floating Particles

private struct FloatingParticles: View {
    let particleCount = 20

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<particleCount, id: \.self) { i in
                FloatingParticle(
                    size: CGFloat.random(in: 4...12),
                    startPosition: CGPoint(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    ),
                    containerSize: geo.size
                )
            }
        }
    }
}

private struct FloatingParticle: View {
    let size: CGFloat
    let startPosition: CGPoint
    let containerSize: CGSize

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: size, height: size)
            .blur(radius: size / 4)
            .position(position)
            .opacity(opacity)
            .onAppear {
                position = startPosition
                withAnimation(.easeInOut(duration: Double.random(in: 0.5...1.5))) {
                    opacity = Double.random(in: 0.3...0.7)
                }
                animate()
            }
    }

    private func animate() {
        let duration = Double.random(in: 8...15)
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            position = CGPoint(
                x: CGFloat.random(in: 0...containerSize.width),
                y: CGFloat.random(in: 0...containerSize.height)
            )
        }
    }
}

// MARK: - Confetti View

private struct ConfettiView: View {
    @State private var confetti: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geo in
            ForEach(confetti) { piece in
                ConfettiPieceView(piece: piece, containerHeight: geo.size.height)
            }
        }
        .onAppear {
            createConfetti()
        }
    }

    private func createConfetti() {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        for i in 0..<50 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.02) {
                let piece = ConfettiPiece(
                    color: colors.randomElement()!,
                    x: CGFloat.random(in: 100...450),
                    rotation: Double.random(in: 0...360)
                )
                confetti.append(piece)
            }
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let rotation: Double
}

private struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    let containerHeight: CGFloat

    @State private var y: CGFloat = -20
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        Rectangle()
            .fill(piece.color)
            .frame(width: 8, height: 12)
            .rotationEffect(.degrees(rotation))
            .position(x: piece.x + CGFloat.random(in: -30...30), y: y)
            .opacity(opacity)
            .onAppear {
                rotation = piece.rotation
                withAnimation(.easeIn(duration: Double.random(in: 2...4))) {
                    y = containerHeight + 50
                    rotation += Double.random(in: 180...720)
                }
                withAnimation(.easeIn(duration: 3).delay(1)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Onboarding Manager

@MainActor
public final class OnboardingManager: ObservableObject {
    public static let shared = OnboardingManager()

    private let onboardingCompleteKey = "hasCompletedOnboarding"

    @Published public var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingCompleteKey)
        }
    }

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }

    public func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
