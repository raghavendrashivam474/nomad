# 🚀 3 Ways to Enable Local Connectivity in Any Project

Because of the **ADR-0010 Hybrid Architecture**, you don't need to copy libraries around or install npm packages. You can use it in whichever way fits your coding style:

---

### Method 1: The "Zero Code Setup" Way (Automatic Injection)
You write **zero script tags** for the transport. Nomad automatically injects `window.NomadTransport` into every preview page.

**`index.html`:**
```html
<!DOCTYPE html>
<html>
<body>
  <h2>My Connected App</h2>
  <script src="app.js"></script> <!-- No transport script tag needed! -->
</body>
</html>
```

**`app.js`:**
```javascript
// NomadTransport is ALREADY available globally!
const transport = new NomadTransport();
```

---

### Method 2: The Standard Web Way (Virtual System Route)
If you want explicit, standard HTML dependency imports, use the built-in system route `/_nomad/transport.js`. **You do NOT need a physical file in your workspace** — Nomad serves it directly from memory!

**`index.html`:**
```html
<!DOCTYPE html>
<html>
<head>
  <!-- Loads directly from Nomad's host memory -->
  <script src="/_nomad/transport.js"></script>
  <script src="app.js"></script>
</head>
<body>
  <h2>My Connected App</h2>
</body>
</html>
```

---

### Method 3: The Single-File HTML Way (Zero Extra Files)
Put your HTML, CSS, JavaScript, and transport logic all in **one single `index.html` file** inside Nomad.

*(This is the exact method you tested on your phone that worked instantly!)*

---

# 📱 The Step-by-Step User Workflow (How 2 Phones Connect)

Whether you build a Chat app, a Multiplayer Game, or a Live Canvas, the connection flow between two devices always follows these **3 steps**:

```text
  [ Device A (Host) ]                             [ Device B (Joiner) ]
          │                                                 │
  1. Click "Host Connection"                                │
     → Token A generated                                    │
          │                                                 │
          ├────────── Send Token A to Device B ────────────>│
          │                                                 │ 2. Paste Token A & click "Join"
          │                                                    → Token B generated
          │                                                 │
          │<───────── Send Token B to Device A ─────────────┤
          │                                                 │
  3. Paste Token B & click "Accept"                         │
          │                                                 │
          ▼                                                 ▼
   ===================================================================
     CONNECTED! Encrypted P2P DataChannel Active (0 Internet Needed)
   ===================================================================
```

1. **Device A (Host):**
   Calls `const offerToken = await transport.createHostOffer();` and displays `offerToken`.
2. **Device B (Joiner):**
   Pastes `offerToken`, calls `const answerToken = await transport.joinHost(offerToken);`, and displays `answerToken`.
3. **Device A (Host):**
   Pastes `answerToken` and calls `await transport.acceptAnswer(answerToken);`.
4. **Done!** Both devices transition to `'connected'`.

---

# 💡 Real-World Reusability Examples

Here is how you use `nomad-transport.js` for different types of applications:

---

### Example A: Sending Real-Time Messages (LAN Chat)

```javascript
const transport = new NomadTransport();

// 1. Listen for connection state changes
transport.on('statechange', (newState) => {
  console.log('Connection Status:', newState); // 'idle' | 'connecting' | 'connected' | 'disconnected'
});

// 2. Listen for incoming messages from the other phone
transport.on('message', (envelope) => {
  if (envelope.type === 'chat.text') {
    console.log(`Received from ${envelope.sender}:`, envelope.payload.text);
  }
});

// 3. Send a message
function sendMessage(text) {
  transport.send('chat.text', { text: text });
}
```

---

### Example B: Collaborative Real-Time Drawing (Multiplayer Canvas)

To show how reusable this is, here is how you build a **shared canvas where drawing on Device A appears on Device B in real-time**:

```javascript
const transport = new NomadTransport();
const canvas = document.getElementById('myCanvas');
const ctx = canvas.getContext('2d');

// Listen for draw events from the remote peer
transport.on('message', (envelope) => {
  if (envelope.type === 'draw.line') {
    const { x1, y1, x2, y2, color } = envelope.payload;
    drawLineOnCanvas(x1, y1, x2, y2, color, false);
  }
});

// When local user draws on their screen:
function onLocalUserDraw(x1, y1, x2, y2) {
  const color = '#3fb950';
  
  // 1. Draw locally
  drawLineOnCanvas(x1, y1, x2, y2, color, true);
  
  // 2. Send draw coordinates over WebRTC
  transport.send('draw.line', { x1, y1, x2, y2, color });
}

function drawLineOnCanvas(x1, y1, x2, y2, color) {
  ctx.strokeStyle = color;
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x2, y2);
  ctx.stroke();
}
```

---

# 📖 Quick API Reference Cheat Sheet

| Method / Event | Usage | Purpose |
|---|---|---|
| `transport.createHostOffer()` | `await transport.createHostOffer()` | (Host) Generates initial connection token |
| `transport.joinHost(token)` | `await transport.joinHost(offerToken)` | (Joiner) Accepts host token, generates answer token |
| `transport.acceptAnswer(token)` | `await transport.acceptAnswer(answerToken)` | (Host) Accepts joiner token, completes connection |
| `transport.send(type, payload)` | `transport.send('game.move', { x: 10, y: 20 })` | Sends JSON data to peer (max 64 KB) |
| `transport.disconnect()` | `transport.disconnect()` | Gracefully closes connection & releases sockets |
| `transport.on('statechange', cb)` | `transport.on('statechange', (state) => ...)` | Fires when state changes (`idle`, `connecting`, `connected`, `disconnected`, `failed`) |
| `transport.on('message', cb)` | `transport.on('message', (envelope) => ...)` | Fires when a message is received from peer |
| `transport.on('error', cb)` | `transport.on('error', (err) => ...)` | Fires on transport/parsing errors |