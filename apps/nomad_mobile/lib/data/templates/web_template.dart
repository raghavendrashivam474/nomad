/// Default starter templates for newly created Web Projects in Nomad.
class WebTemplate {
  const WebTemplate._();

  static const String indexHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Nomad Web Project</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="container">
    <h1>Welcome to Nomad</h1>
    <p>Your mobile web lab is ready. Edit files to see your project evolve.</p>
    <button id="action-btn">Click Me</button>
    <p id="output"></p>
  </div>
  <script src="script.js"></script>
</body>
</html>
''';

  static const String styleCss = '''* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  background-color: #0f172a;
  color: #f8fafc;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  padding: 1.5rem;
}

.container {
  text-align: center;
  max-width: 480px;
}

h1 {
  font-size: 2rem;
  color: #38bdf8;
  margin-bottom: 0.75rem;
}

p {
  font-size: 1rem;
  line-height: 1.5;
  color: #94a3b8;
  margin-bottom: 1.5rem;
}

button {
  background-color: #38bdf8;
  color: #0f172a;
  font-size: 1rem;
  font-weight: 600;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  cursor: pointer;
}

button:hover {
  background-color: #0284c7;
}

#output {
  margin-top: 1rem;
  font-weight: 600;
  color: #4ade80;
}
''';

  static const String scriptJs = '''// Nomad Web Project Starter Script
document.addEventListener('DOMContentLoaded', () => {
  const btn = document.getElementById('action-btn');
  const output = document.getElementById('output');

  if (btn && output) {
    btn.addEventListener('click', () => {
      output.textContent = 'Nomad Web Lab is running!';
    });
  }
});
''';
}
