// game.js

// --- DOM Elements & Setup ---
const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const scoreValue = document.getElementById('scoreValue');
const gameOverScreen = document.getElementById('gameOverScreen');
const finalScore = document.getElementById('finalScore');
const restartBtn = document.getElementById('restartBtn');
const startScreen = document.getElementById('startScreen');
const startBtn = document.getElementById('startBtn');
const uploadBtn = document.getElementById('uploadBtn');
const imageUploader = document.getElementById('imageUploader');
const airfieldBtn = document.getElementById('airfieldBtn');
const gameContainer = document.getElementById('gameContainer');

const creditsBtn = document.getElementById('creditsBtn');

// --- Game State ---
let triangles = [];
let score = 0;
let isGameOver = false;
let animationFrameId;
let spawnIntervalId;

// Input Modes: 'normal', 'selectingAirfieldPoint1', 'selectingAirfieldPoint2'
let inputMode = 'normal';
let airfieldLine = null; // [ {x, y}, {x, y} ]
let airfieldStartPoint = null;
let selectedTriangle = null;

// Assets
let backgroundImage = null;
const bgMusic = new Audio('assets/background-music.mp3');
bgMusic.loop = true;
const explosionSound = new Audio('assets/explosion.wav');

// --- Canvas Resizing for Mobile ---
function resizeCanvas() {
    // Handle high-DPI retina displays for sharp rendering
    const dpr = window.devicePixelRatio || 1;
    const rect = gameContainer.getBoundingClientRect();
    
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    
    ctx.scale(dpr, dpr);
    canvas.style.width = `${rect.width}px`;
    canvas.style.height = `${rect.height}px`;
}
window.addEventListener('resize', resizeCanvas);
resizeCanvas();

// --- Bouncing Triangle Class ---
class BouncingTriangle {
    constructor(x, y, vx, vy) {
        this.position = { x, y };
        this.velocity = { dx: vx, dy: vy };
        this.pathIndex = 0;
        this.isLanded = false;
        this.state = 'bouncing'; // 'bouncing' or 'followingPath'
        this.size = 50;
        this.speed = 1.75;
        // Replaces this.path = [];
        this.clickX = [];
        this.clickY = [];
        this.clickDrag = [];
    }

    addClick(x, y, dragging) {
        this.clickX.push(x);
        this.clickY.push(y);
        this.clickDrag.push(dragging);
    }

    update(bounds, airfield, isSelected = false) {
        // Apply a 50% speed penalty if selected, otherwise 100% speed
        const speedMultiplier = isSelected ? 0.5 : 1.0;

        if (this.state === 'bouncing') {
            this.updateBouncing(bounds, speedMultiplier);
        } else if (this.state === 'followingPath') {
            this.updatePathFollowing(speedMultiplier);
        }
        this.checkForLanding(airfield);
    }

    updateBouncing(bounds, speedMultiplier) {
        // Multiply the velocity applied this frame by our speed modifier
        this.position.x += this.velocity.dx * speedMultiplier;
        this.position.y += this.velocity.dy * speedMultiplier;

        const halfSize = this.size / 2;
        // Bounce off edges
        if (this.position.x - halfSize < 0 || this.position.x + halfSize > bounds.width) {
            this.velocity.dx *= -1;
            this.position.x = Math.max(halfSize, Math.min(bounds.width - halfSize, this.position.x));
        }
        if (this.position.y - halfSize < 0 || this.position.y + halfSize > bounds.height) {
            this.velocity.dy *= -1;
            this.position.y = Math.max(halfSize, Math.min(bounds.height - halfSize, this.position.y));
        }
    }

    updatePathFollowing(speedMultiplier) {
        if (this.clickX.length === 0 || this.pathIndex >= this.clickX.length) {
            this.state = 'bouncing';
            return;
        }

        const targetX = this.clickX[this.pathIndex];
        const targetY = this.clickY[this.pathIndex];
        const dx = targetX - this.position.x;
        const dy = targetY - this.position.y;
        const distance = Math.hypot(dx, dy);

        if (distance < 5) {
            this.pathIndex++;
            if (this.pathIndex >= this.clickX.length && this.clickX.length > 1) {
                const lastX = this.clickX[this.clickX.length - 1];
                const lastY = this.clickY[this.clickY.length - 1];
                const secondLastX = this.clickX[this.clickX.length - 2];
                const secondLastY = this.clickY[this.clickY.length - 2];
                const dirX = lastX - secondLastX;
                const dirY = lastY - secondLastY;
                const mag = Math.hypot(dirX, dirY);
                if (mag > 0) {
                    this.velocity = { dx: (dirX / mag) * this.speed, dy: (dirY / mag) * this.speed };
                }
            }
        } else {
            this.velocity = { dx: (dx / distance) * this.speed, dy: (dy / distance) * this.speed };
            this.position.x += this.velocity.dx * speedMultiplier;
            this.position.y += this.velocity.dy * speedMultiplier;
        }
    }

    checkForLanding(airfield) {
        if (!airfield || airfield.length !== 2) return;
        const p1 = airfield[0];
        const p2 = airfield[1];

        const lineVec = { dx: p2.x - p1.x, dy: p2.y - p1.y };
        const pointVec = { dx: this.position.x - p1.x, dy: this.position.y - p1.y };
        const lineLenSq = lineVec.dx * lineVec.dx + lineVec.dy * lineVec.dy;

        if (lineLenSq === 0) return;

        const t = Math.max(0, Math.min(1, (pointVec.dx * lineVec.dx + pointVec.dy * lineVec.dy) / lineLenSq));
        const closestPoint = { x: p1.x + t * lineVec.dx, y: p1.y + t * lineVec.dy };

        const distanceSq = Math.pow(this.position.x - closestPoint.x, 2) + Math.pow(this.position.y - closestPoint.y, 2);
        const landingRadiusSq = Math.pow(this.size / 2, 2);

        if (distanceSq < landingRadiusSq) {
            this.isLanded = true;
        }
    }

    contains(x, y) {
        // Calculate the exact distance from the touch point to the center of the plane
        const distance = Math.hypot(this.position.x - x, this.position.y - y);
        
        // Match this perfectly to your visual circle: (halfSize + 8)
        const hitboxRadius = (this.size / 2) + 8;
        
        // Return true only if the touch is inside that exact circular radius
        return distance <= hitboxRadius;
    }

    draw(ctx, isSelected = false) {
        const halfSize = this.size / 2;
        const angle = Math.atan2(this.velocity.dy, this.velocity.dx) + (Math.PI / 2);

        ctx.save();
        ctx.translate(this.position.x, this.position.y);

        // NEW: Draw the yellow selection ring if this plane is currently selected
        if (isSelected) {
            ctx.strokeStyle = '#FFCC00'; // Standard iOS Yellow
            ctx.lineWidth = 3;
            ctx.beginPath();
            // We make the radius slightly larger than the triangle (halfSize + 8)
            ctx.arc(0, 0, halfSize + 8, 0, Math.PI * 2); 
            ctx.stroke();
        }

        ctx.rotate(angle);

        ctx.fillStyle = '#FF2D55'; // SwiftUI .pink
        ctx.beginPath();
        ctx.moveTo(0, -halfSize);              
        ctx.lineTo(halfSize, halfSize);        
        ctx.lineTo(-halfSize, halfSize);       
        ctx.closePath();
        ctx.fill();

        ctx.restore();
    }
}

// --- Spawning Logic ---
function spawnTriangle() {
    if (isGameOver || triangles.length >= 20) return;

    const bounds = gameContainer.getBoundingClientRect();
    let x, y;
    const offset = 100;
    const edge = Math.floor(Math.random() * 4);

    switch (edge) {
        case 0: x = Math.random() * bounds.width; y = -offset; break;
        case 1: x = bounds.width + offset; y = Math.random() * bounds.height; break;
        case 2: x = Math.random() * bounds.width; y = bounds.height + offset; break;
        case 3: x = -offset; y = Math.random() * bounds.height; break;
    }

    const targetX = bounds.width / 2;
    const targetY = bounds.height / 2;
    const dx = targetX - x;
    const dy = targetY - y;
    const mag = Math.hypot(dx, dy);

    const speed = 1.75;
    const vx = (dx / mag) * speed;
    const vy = (dy / mag) * speed;

    triangles.push(new BouncingTriangle(x, y, vx, vy));
}

// --- Main Game Loop ---
function update() {
    if (isGameOver) return;

    const bounds = gameContainer.getBoundingClientRect();
    
    // Clear Canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw Background Image
    if (backgroundImage) {
        // Simple "aspect ratio fit" calculation omitted for brevity; drawing stretched here
        ctx.drawImage(backgroundImage, 0, 0, canvas.width / (window.devicePixelRatio || 1), canvas.height / (window.devicePixelRatio || 1));
    }

    // Draw Airfield
    if (airfieldLine && airfieldLine.length === 2) {
        ctx.strokeStyle = '#007AFF'; // SwiftUI .blue
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.moveTo(airfieldLine[0].x, airfieldLine[0].y);
        ctx.lineTo(airfieldLine[1].x, airfieldLine[1].y);
        ctx.stroke();
    }

    // Process Triangles
    for (let i = triangles.length - 1; i >= 0; i--) {
        const tri = triangles[i];
        // Change this line:
        // tri.update(bounds, airfieldLine);
        
        // To this:
        tri.update(bounds, airfieldLine, tri === selectedTriangle);

        if (tri.isLanded) {
            score++;
            scoreValue.innerText = score;
            triangles.splice(i, 1);
            continue;
        }

        // Draw Path
        // Draw Path (Using OSS Logic)
        if (tri.state === 'followingPath' && tri.clickX.length > 0 && tri.pathIndex < tri.clickX.length) {
            ctx.strokeStyle = '#AF52DE'; // SwiftUI .purple
            ctx.lineWidth = 3;
            
            // OSS Logic applied AS IS, starting from the plane's current pathIndex
            for (let j = tri.pathIndex; j < tri.clickX.length; j += 1) {
                ctx.beginPath();
                
                // If dragging and not the first point, connect to the previous point
                if (tri.clickDrag[j] && j > tri.pathIndex) {
                    ctx.moveTo(tri.clickX[j - 1], tri.clickY[j - 1]);
                } else {
                    // Otherwise, offset by 1 pixel to draw a standalone dot
                    ctx.moveTo(tri.clickX[j] - 1, tri.clickY[j]);
                }
                
                ctx.lineTo(tri.clickX[j], tri.clickY[j]);
                ctx.stroke();
            }
        }

        // Change this line:
        // tri.draw(ctx);
        
        // To this:
        tri.draw(ctx, tri === selectedTriangle);
    }

    checkCollisions();
    animationFrameId = requestAnimationFrame(update);
}

function checkCollisions() {
    for (let i = 0; i < triangles.length - 1; i++) {
        for (let j = i + 1; j < triangles.length; j++) {
            const t1 = triangles[i];
            const t2 = triangles[j];
            const distance = Math.hypot(t1.position.x - t2.position.x, t1.position.y - t2.position.y);
            
            if (distance < t1.size) {
                gameOver();
                return;
            }
        }
    }
}

// --- Inputs & Gestures ---
function getPointerPos(e) {
    const rect = canvas.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
}

canvas.addEventListener('pointerdown', (e) => {
    const pos = getPointerPos(e);

    if (inputMode === 'selectingAirfieldPoint1') {
        airfieldStartPoint = pos;
        inputMode = 'selectingAirfieldPoint2';
    } else if (inputMode === 'selectingAirfieldPoint2') {
        airfieldLine = [airfieldStartPoint, pos];
        inputMode = 'normal';
        airfieldStartPoint = null;
    } else if (inputMode === 'normal') {
        selectedTriangle = triangles.find(t => t.contains(pos.x, pos.y));
        if (selectedTriangle) {
            // Reset the OSS arrays
            selectedTriangle.clickX = [];
            selectedTriangle.clickY = [];
            selectedTriangle.clickDrag = [];
            selectedTriangle.pathIndex = 0;
            selectedTriangle.state = 'followingPath';
            
            // Record the initial touch (dragging is false)
            selectedTriangle.addClick(pos.x, pos.y, false);
        }
    }
});

canvas.addEventListener('pointermove', (e) => {
    if (inputMode !== 'normal' || !selectedTriangle) return;
    
    const pos = getPointerPos(e);
    // Record continuous movement (dragging is true)
    selectedTriangle.addClick(pos.x, pos.y, true);
});

canvas.addEventListener('pointerup', () => {
    selectedTriangle = null;
});

// --- Game Controls ---
function startGame() {
    startScreen.classList.add('hidden');
    bgMusic.play().catch(e => console.log("Audio play blocked", e));
    resetGame();
}

function gameOver() {
    isGameOver = true;
    cancelAnimationFrame(animationFrameId);
    clearInterval(spawnIntervalId);
    
    // Play explosion sound effect instantly
    // cloneNode(true) ensures if two planes crash at the exact same millisecond, 
    // or if you crash rapidly, the audio file overlaps and plays successfully every time.
    explosionSound.cloneNode(true).play().catch(e => console.log("Audio blocked: ", e));
    
    finalScore.innerText = score;
    
    // Show menus and the credits button again
    gameOverScreen.classList.remove('hidden');
    creditsBtn.classList.remove('hidden');
}

function resetGame() {
    isGameOver = false;
    score = 0;
    scoreValue.innerText = score;
    triangles = [];
    
    // Hide menus and the credits button when the game is active
    gameOverScreen.classList.add('hidden');
    creditsBtn.classList.add('hidden');
    
    clearInterval(spawnIntervalId);
    spawnIntervalId = setInterval(spawnTriangle, 2000);
    spawnTriangle(); 
    
    cancelAnimationFrame(animationFrameId);
    update();
}

// --- UI Button Listeners ---
startBtn.addEventListener('click', startGame);
restartBtn.addEventListener('click', resetGame);

airfieldBtn.addEventListener('click', () => {
    inputMode = 'selectingAirfieldPoint1';
    airfieldLine = null;
});

uploadBtn.addEventListener('click', () => imageUploader.click());

imageUploader.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) {
        const reader = new FileReader();
        reader.onload = function(event) {
            const img = new Image();
            img.onload = () => { backgroundImage = img; };
            img.src = event.target.result;
        }
        reader.readAsDataURL(file);
    }
});

// Start the rendering engine immediately on page load so 
// backgrounds and airfields draw before the game starts.
update();