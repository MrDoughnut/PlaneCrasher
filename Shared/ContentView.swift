//
//  ContentView.swift
//  Shared
//
//  Created on 8/5/25.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - Triangle Shape
struct Triangle: Shape {
	func path(in rect: CGRect) -> Path {
		var path = Path()
		path.move(to: CGPoint(x: rect.midX, y: rect.minY))
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
		path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
		path.closeSubpath()
		return path
	}
}

// MARK: - Bouncing Triangle Model
struct BouncingTriangle: Identifiable {
	let id = UUID()
	var position: CGPoint
	var velocity: CGVector
	var path: [CGPoint] = []
	var pathIndex: Int = 0
	var isLanded: Bool = false
	
	enum MovementState {
		case bouncing
		case followingPath
	}
	var state: MovementState = .bouncing
	
	let size: CGFloat = 50
	let speed: CGFloat = 1.75

	/// Updates the triangle's position based on its state and checks for landing.
	mutating func update(in bounds: CGRect, airfieldLine: [CGPoint]?) {
		switch state {
		case .bouncing:
			updateBouncing(in: bounds, airfieldLine: airfieldLine)
		case .followingPath:
			updatePathFollowing(in: bounds, airfieldLine: airfieldLine)
		}
	}
	
	/// Common logic to check for landing on the airfield line.
	private mutating func checkForLanding(airfieldLine: [CGPoint]?) {
		guard let line = airfieldLine, line.count == 2 else { return }
		let p1 = line[0]
		let p2 = line[1]
		let triangleCenter = self.position

		let lineVec = CGVector(dx: p2.x - p1.x, dy: p2.y - p1.y)
		let pointVec = CGVector(dx: triangleCenter.x - p1.x, dy: triangleCenter.y - p1.y)
		let lineLenSq = lineVec.dx * lineVec.dx + lineVec.dy * lineVec.dy
		
		guard lineLenSq > 0.0 else { return }

		let t = max(0, min(1, (pointVec.dx * lineVec.dx + pointVec.dy * lineVec.dy) / lineLenSq))
		let closestPoint = CGPoint(x: p1.x + t * lineVec.dx, y: p1.y + t * lineVec.dy)
		
		let dx = triangleCenter.x - closestPoint.x
		let dy = triangleCenter.y - closestPoint.y
		let distanceSq = dx * dx + dy * dy
		
		let landingRadius = size / 2
		if distanceSq < (landingRadius * landingRadius) {
			isLanded = true
		}
	}
	
	private mutating func updateBouncing(in bounds: CGRect, airfieldLine: [CGPoint]?) {
		position.x += velocity.dx
		position.y += velocity.dy

		if position.x - size / 2 < bounds.minX || position.x + size / 2 > bounds.maxX {
			velocity.dx *= -1
		}
		if position.y - size / 2 < bounds.minY || position.y + size / 2 > bounds.maxY {
			velocity.dy *= -1
		}
		
		position.x = max(bounds.minX + size / 2, min(bounds.maxX - size / 2, position.x))
		position.y = max(bounds.minY + size / 2, min(bounds.maxY - size / 2, position.y))

		checkForLanding(airfieldLine: airfieldLine)
	}
	
	private mutating func updatePathFollowing(in bounds: CGRect, airfieldLine: [CGPoint]?) {
		guard !path.isEmpty, pathIndex < path.count else {
			state = .bouncing
			return
		}
		
		let targetPoint = path[pathIndex]
		let vectorToTarget = CGVector(dx: targetPoint.x - position.x, dy: targetPoint.y - position.y)
		let distance = sqrt(vectorToTarget.dx * vectorToTarget.dx + vectorToTarget.dy * vectorToTarget.dy)
		
		if distance < 5 {
			pathIndex += 1
			if pathIndex >= path.count, path.count > 1 {
				let lastPoint = path[path.count - 1]
				let secondLastPoint = path[path.count - 2]
				let directionVector = CGVector(dx: lastPoint.x - secondLastPoint.x, dy: lastPoint.y - secondLastPoint.y)
				let magnitude = sqrt(directionVector.dx * directionVector.dx + directionVector.dy * directionVector.dy)
				if magnitude > 0 {
					velocity = CGVector(dx: (directionVector.dx / magnitude) * speed, dy: (directionVector.dy / magnitude) * speed)
				}
			}
		} else {
			velocity = CGVector(dx: (vectorToTarget.dx / distance) * speed, dy: (vectorToTarget.dy / distance) * speed)
			position.x += velocity.dx
			position.y += velocity.dy
		}
		checkForLanding(airfieldLine: airfieldLine)
	}
	
	func contains(_ point: CGPoint) -> Bool {
		return CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size).contains(point)
	}
}

// MARK: - Main Content View
struct ContentView: View {
	enum InputMode {
		case normal
		case selectingAirfieldPoint1
		case selectingAirfieldPoint2
	}
	
	@State private var triangles: [BouncingTriangle] = []
	@State private var selectedTriangleID: UUID?
	@State private var backgroundImage: Image?
	@State private var originalImageSize: CGSize?
	@State private var imageFrame: CGRect = .zero
	
	@State private var airfieldLine: [CGPoint]?
	@State private var inputMode: InputMode = .normal
	@State private var airfieldStartPoint: CGPoint?
	
	@State private var score: Int = 0
	@State private var isGameOver: Bool = false
	
	@State private var audioPlayer: AVAudioPlayer?
	@State private var explosionPlayer: AVAudioPlayer? // Player for the explosion sound
	
	#if os(iOS)
	@State private var isShowingImagePicker = false
	@State private var inputImage: UIImage?
	#endif

	let addTriangleTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
	let renderTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()

	var body: some View {
		ZStack {
			gameView
			
			if isGameOver {
				Color.black.opacity(0.75).ignoresSafeArea()
				VStack {
					Text("Game Over")
						.font(.largeTitle)
						.fontWeight(.bold)
						.foregroundColor(.red)
					Text("Final Score: \(score)")
						.font(.title2)
						.foregroundColor(.white)
						.padding(.bottom, 40)
					Button("Restart") {
						restartGame()
					}
					.font(.title)
					.padding()
					.background(Color.white)
					.foregroundColor(.black)
					.cornerRadius(10)
				}
			}
		}
	}
	
	var gameView: some View {
		ZStack {
			if let backgroundImage = backgroundImage {
				backgroundImage
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else {
				Color.white
				#if os(macOS)
				Text("Drop an image here to set the background").foregroundColor(.gray).font(.title)
				#endif
			}

			GeometryReader { geometry in
				Canvas { context, size in
					if let line = airfieldLine, line.count == 2 {
						var path = Path()
						path.move(to: line[0])
						path.addLine(to: line[1])
						context.stroke(path, with: .color(.blue), lineWidth: 5)
					}
					
					for triangle in triangles {
						if triangle.state == .followingPath, !triangle.path.isEmpty, triangle.pathIndex < triangle.path.count {
							var pathToDraw = Path()
							pathToDraw.move(to: triangle.position)
							pathToDraw.addLines(Array(triangle.path[triangle.pathIndex...]))
							context.stroke(pathToDraw, with: .color(.purple), lineWidth: 3)
						}
					}
					
					for triangle in triangles {
						let triangleRect = CGRect(x: triangle.position.x - triangle.size / 2, y: triangle.position.y - triangle.size / 2, width: triangle.size, height: triangle.size)
						context.fill(Triangle().path(in: triangleRect), with: .color(.pink))
					}
				}
				.gesture(airfieldSelectionGesture.simultaneously(with: pathDrawingGesture))
				.onReceive(renderTimer) { _ in
					guard !isGameOver else { return }
					
					for i in triangles.indices {
						triangles[i].update(in: self.imageFrame, airfieldLine: self.airfieldLine)
					}
					
					let landedCount = triangles.filter { $0.isLanded }.count
					if landedCount > 0 {
						score += landedCount
						triangles.removeAll { $0.isLanded }
					}
					
					checkForCollisions()
				}
				.onReceive(addTriangleTimer) { _ in
					guard !isGameOver else { return }
					addNewTriangle(in: geometry.size)
				}
				.onAppear {
					updateImageFrame(containerSize: geometry.size)
					addNewTriangle(in: geometry.size)
					playBundledMusic()
				}
				.onChange(of: geometry.size) { newSize in
					updateImageFrame(containerSize: newSize)
				}
			}
		}
		.ignoresSafeArea()
		.navigationTitle("PlaneCrasher")
		.overlay(alignment: .topLeading) {
			Text("Score: \(score)")
				.font(.title)
				.fontWeight(.bold)
				.foregroundColor(.black)
				.padding(12)
				.background(.thinMaterial, in: Capsule())
				.padding()
		}
		.overlay(alignment: .bottom) {
			HStack {
				#if os(iOS)
				Button {
					self.isShowingImagePicker = true
				} label: {
					Label("Select Background", systemImage: "photo")
				}
				#endif
				
				Button {
					self.inputMode = .selectingAirfieldPoint1
					self.airfieldLine = nil
				} label: {
					Label("Select Airfield", systemImage: "airplane.departure")
				}
			}
			.padding()
			.background(.thinMaterial, in: Capsule())
			.padding()
		}
		#if os(iOS)
		.sheet(isPresented: $isShowingImagePicker) { ImagePicker(image: self.$inputImage) }
		.onChange(of: inputImage) { newImage in
			guard let newImage = newImage else { return }
			self.backgroundImage = Image(uiImage: newImage)
			self.originalImageSize = newImage.size
		}
		#elseif os(macOS)
		.onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
			guard let provider = providers.first else { return false }
			
			_ = provider.loadObject(ofClass: URL.self) { url, error in
				if let url = url, let image = NSImage(contentsOf: url) {
					DispatchQueue.main.async {
						self.backgroundImage = Image(nsImage: image)
						self.originalImageSize = image.size
					}
				}
			}
			return true
		}
		#endif
	}
	
	private func checkForCollisions() {
		guard triangles.count > 1 else { return }
		
		for i in 0..<(triangles.count - 1) {
			for j in (i + 1)..<triangles.count {
				let triangle1 = triangles[i]
				let triangle2 = triangles[j]
				
				let dx = triangle1.position.x - triangle2.position.x
				let dy = triangle1.position.y - triangle2.position.y
				let distance = sqrt(dx * dx + dy * dy)
				
				if distance < triangle1.size {
					isGameOver = true
					playExplosionSound() // Play explosion sound
					// Soundtrack is no longer stopped here.
					return
				}
			}
		}
	}
	
	private func restartGame() {
		score = 0
		triangles.removeAll()
		isGameOver = false
		
		// Soundtrack continues playing or restarts if it was stopped.
		if audioPlayer?.isPlaying == false {
			audioPlayer?.currentTime = 0
			audioPlayer?.play()
		} else if audioPlayer == nil {
			playBundledMusic()
		}
	}
	
	private func playBundledMusic() {
		guard let url = Bundle.main.url(forResource: "11 Sky's Fury (Thunderbird Battle - Gameplay Version)", withExtension: "mp3") else {
			print("Default 11 Sky's Fury (Thunderbird Battle - Gameplay Version).mp3 not found in bundle.")
			return
		}
		playMusic(from: url)
	}
	
	private func playExplosionSound() {
		guard let url = Bundle.main.url(forResource: "explosion", withExtension: "wav") else {
			print("Default explosion.wav not found in bundle.")
			return
		}
		do {
			explosionPlayer = try AVAudioPlayer(contentsOf: url)
			explosionPlayer?.play()
		} catch {
			print("Error playing explosion sound: \(error.localizedDescription)")
		}
	}
	
	private func playMusic(from url: URL) {
		do {
			audioPlayer?.stop()
			audioPlayer = try AVAudioPlayer(contentsOf: url)
			audioPlayer?.numberOfLoops = -1
			audioPlayer?.prepareToPlay()
			audioPlayer?.play()
		} catch {
			print("Error setting up audio player: \(error.localizedDescription)")
		}
	}
	
	private func updateImageFrame(containerSize: CGSize) {
		guard let imageSize = originalImageSize else {
			self.imageFrame = CGRect(origin: .zero, size: containerSize)
			return
		}

		let containerAspect = containerSize.width / containerSize.height
		let imageAspect = imageSize.width / imageSize.height

		var newSize: CGSize
		if containerAspect > imageAspect {
			newSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
		} else {
			newSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
		}

		let origin = CGPoint(x: (containerSize.width - newSize.width) / 2, y: (containerSize.height - newSize.height) / 2)
		self.imageFrame = CGRect(origin: origin, size: newSize)
	}

	var airfieldSelectionGesture: some Gesture {
		DragGesture(minimumDistance: 0, coordinateSpace: .local)
			.onEnded { value in
				switch inputMode {
				case .selectingAirfieldPoint1:
					airfieldStartPoint = value.location
					inputMode = .selectingAirfieldPoint2
				case .selectingAirfieldPoint2:
					if let firstPoint = airfieldStartPoint {
						let secondPoint = value.location
						airfieldLine = [firstPoint, secondPoint]
					}
					inputMode = .normal
					airfieldStartPoint = nil
				case .normal:
					break
				}
			}
	}
	
	var pathDrawingGesture: some Gesture {
		DragGesture(minimumDistance: 0, coordinateSpace: .local)
			.onChanged { value in
				guard inputMode == .normal else { return }
				if selectedTriangleID == nil {
					if let index = triangles.firstIndex(where: { $0.contains(value.startLocation) }) {
						selectedTriangleID = triangles[index].id
						triangles[index].path.removeAll()
						triangles[index].pathIndex = 0
						triangles[index].state = .followingPath
					}
				}
				
				if let selectedID = selectedTriangleID, let index = triangles.firstIndex(where: { $0.id == selectedID }) {
					triangles[index].path.append(value.location)
				}
			}
			.onEnded { _ in
				if selectedTriangleID != nil {
					selectedTriangleID = nil
				}
			}
	}

	private func addNewTriangle(in bounds: CGSize) {
		guard triangles.count < 20 else { return }
		
		var newPosition: CGPoint
		let spawnOffset: CGFloat = 100
		
		let edge = Int.random(in: 0...3)
		switch edge {
		case 0: newPosition = CGPoint(x: CGFloat.random(in: 0...bounds.width), y: -spawnOffset)
		case 1: newPosition = CGPoint(x: bounds.width + spawnOffset, y: CGFloat.random(in: 0...bounds.height))
		case 2: newPosition = CGPoint(x: CGFloat.random(in: 0...bounds.width), y: bounds.height + spawnOffset)
		default: newPosition = CGPoint(x: -spawnOffset, y: CGFloat.random(in: 0...bounds.height))
		}
		
		let targetPoint = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
		let directionVector = CGVector(dx: targetPoint.x - newPosition.x, dy: targetPoint.y - newPosition.y)
		let magnitude = sqrt(directionVector.dx * directionVector.dx + directionVector.dy * directionVector.dy)
		
		let speed: CGFloat = 1.75
		let velocity = CGVector(dx: (directionVector.dx / magnitude) * speed, dy: (directionVector.dy / magnitude) * speed)
		
		let newTriangle = BouncingTriangle(position: newPosition, velocity: velocity)
		triangles.append(newTriangle)
	}
}

#if os(iOS)
// MARK: - ImagePicker for iOS (UIViewControllerRepresentable)
struct ImagePicker: UIViewControllerRepresentable {
	@Binding var image: UIImage?

	func makeUIViewController(context: Context) -> UIImagePickerController {
		let picker = UIImagePickerController()
		picker.delegate = context.coordinator
		return picker
	}

	func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
		let parent: ImagePicker
		init(_ parent: ImagePicker) { self.parent = parent }
		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
			if let uiImage = info[.originalImage] as? UIImage { parent.image = uiImage }
			picker.dismiss(animated: true)
		}
		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
	}
}
#endif

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
