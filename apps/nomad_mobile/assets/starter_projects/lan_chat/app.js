/**
 * Nomad LAN Chat — Application Controller
 * Binds DOM interactions to the NomadTransport WebRTC driver.
 */
document.addEventListener('DOMContentLoaded', () => {
  const transport = new NomadTransport();

  // --- DOM Elements ---
  const localPeerLabel = document.getElementById('localPeerLabel');
  const statusBadge = document.getElementById('statusBadge');
  const disconnectBtn = document.getElementById('disconnectBtn');
  const connectPanel = document.getElementById('connectPanel');
  const chatPanel = document.getElementById('chatPanel');

  // Tabs
  const tabHost = document.getElementById('tabHost');
  const tabJoin = document.getElementById('tabJoin');
  const hostSection = document.getElementById('hostSection');
  const joinSection = document.getElementById('joinSection');

  // Host Flow
  const btnCreateOffer = document.getElementById('btnCreateOffer');
  const offerOutputGroup = document.getElementById('offerOutputGroup');
  const offerTokenOutput = document.getElementById('offerTokenOutput');
  const btnCopyOffer = document.getElementById('btnCopyOffer');
  const hostStep2 = document.getElementById('hostStep2');
  const hostAnswerInput = document.getElementById('hostAnswerInput');
  const btnAcceptAnswer = document.getElementById('btnAcceptAnswer');

  // Join Flow
  const joinOfferInput = document.getElementById('joinOfferInput');
  const btnJoinOffer = document.getElementById('btnJoinOffer');
  const joinStep2 = document.getElementById('joinStep2');
  const joinAnswerOutput = document.getElementById('joinAnswerOutput');
  const btnCopyAnswer = document.getElementById('btnCopyAnswer');

  // Chat Flow
  const messageStream = document.getElementById('messageStream');
  const chatForm = document.getElementById('chatForm');
  const messageInput = document.getElementById('messageInput');
  const toast = document.getElementById('toast');

  // Set Local Peer Identifier
  localPeerLabel.textContent = transport.localPeerId;

  // --- State Machine UI Binding ---
  transport.on('statechange', (newState) => {
    statusBadge.textContent = newState.toUpperCase();
    statusBadge.className = `status-badge state-${newState}`;

    if (newState === 'connected') {
      connectPanel.classList.add('hidden');
      chatPanel.classList.remove('hidden');
      disconnectBtn.classList.remove('hidden');
      messageInput.focus();
      showToast('Connected to peer!');
    } else {
      chatPanel.classList.add('hidden');
      connectPanel.classList.remove('hidden');
      disconnectBtn.classList.add('hidden');
    }

    if (newState === 'failed') {
      showToast('Connection failed. Please retry.');
    }
  });

  transport.on('peer_disconnected', () => {
    appendSystemMessage('Peer disconnected.');
    showToast('Peer disconnected.');
  });

  transport.on('message', (envelope) => {
    if (envelope.type === 'chat.text') {
      appendChatMessage(envelope.payload.text, 'remote', envelope.ts, envelope.sender);
    }
  });

  transport.on('error', (err) => {
    console.error('[App] Transport error:', err);
    showToast(`Error: ${err.stage || 'Transport error'}`);
  });

  // --- Tab Switching ---
  tabHost.addEventListener('click', () => {
    tabHost.classList.add('active');
    tabJoin.classList.remove('active');
    hostSection.classList.add('active');
    joinSection.classList.remove('active');
  });

  tabJoin.addEventListener('click', () => {
    tabJoin.classList.add('active');
    tabHost.classList.remove('active');
    joinSection.classList.add('active');
    hostSection.classList.remove('active');
  });

  // --- Host Workflow ---
  btnCreateOffer.addEventListener('click', async () => {
    btnCreateOffer.disabled = true;
    btnCreateOffer.textContent = 'Generating Token...';
    try {
      const offerToken = await transport.createHostOffer();
      offerTokenOutput.value = offerToken;
      offerOutputGroup.classList.remove('hidden');
      hostStep2.classList.remove('disabled');
      btnCreateOffer.textContent = 'Offer Generated';
      showToast('Offer Token Ready. Copy and share it!');
    } catch (err) {
      btnCreateOffer.disabled = false;
      btnCreateOffer.textContent = 'Generate Offer Token';
    }
  });

  btnCopyOffer.addEventListener('click', () => {
    copyToClipboard(offerTokenOutput.value, 'Offer Token copied!');
  });

  hostAnswerInput.addEventListener('input', () => {
    btnAcceptAnswer.disabled = !hostAnswerInput.value.trim();
  });

  btnAcceptAnswer.addEventListener('click', async () => {
    btnAcceptAnswer.disabled = true;
    btnAcceptAnswer.textContent = 'Connecting...';
    try {
      await transport.acceptAnswer(hostAnswerInput.value.trim());
    } catch (err) {
      btnAcceptAnswer.disabled = false;
      btnAcceptAnswer.textContent = 'Connect to Device B';
    }
  });

  // --- Join Workflow ---
  btnJoinOffer.addEventListener('click', async () => {
    const offerToken = joinOfferInput.value.trim();
    if (!offerToken) {
      showToast('Please paste an Offer Token first.');
      return;
    }

    btnJoinOffer.disabled = true;
    btnJoinOffer.textContent = 'Generating Answer...';

    try {
      const answerToken = await transport.joinHost(offerToken);
      joinAnswerOutput.value = answerToken;
      joinStep2.classList.remove('hidden');
      btnJoinOffer.textContent = 'Answer Generated';
      showToast('Answer generated. Share it with Device A!');
    } catch (err) {
      btnJoinOffer.disabled = false;
      btnJoinOffer.textContent = 'Generate Answer Token';
    }
  });

  btnCopyAnswer.addEventListener('click', () => {
    copyToClipboard(joinAnswerOutput.value, 'Answer Token copied!');
  });

  // --- Chat Submission ---
  chatForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const text = messageInput.value.trim();
    if (!text) return;

    const sent = transport.send('chat.text', { text: text });
    if (sent) {
      appendChatMessage(text, 'self', Date.now(), transport.localPeerId);
      messageInput.value = '';
    } else {
      showToast('Failed to send message: channel closed.');
    }
  });

  // --- Disconnect Button ---
  disconnectBtn.addEventListener('click', () => {
    if (confirm('Disconnect from peer?')) {
      transport.disconnect();
    }
  });

  // --- UI Helpers ---
  function appendChatMessage(text, origin, timestamp, senderId) {
    const bubble = document.createElement('div');
    bubble.className = `message-bubble ${origin}`;

    const content = document.createElement('span');
    content.className = 'msg-text';
    content.textContent = text;

    const meta = document.createElement('span');
    meta.className = 'msg-meta';
    const timeStr = new Date(timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    meta.textContent = `${origin === 'self' ? 'You' : senderId.substring(0, 6)} • ${timeStr}`;

    bubble.appendChild(content);
    bubble.appendChild(meta);
    messageStream.appendChild(bubble);
    messageStream.scrollTop = messageStream.scrollHeight;
  }

  function appendSystemMessage(text) {
    const msg = document.createElement('div');
    msg.className = 'system-message';
    msg.innerHTML = `<span>${text}</span>`;
    messageStream.appendChild(msg);
    messageStream.scrollTop = messageStream.scrollHeight;
  }

  function showToast(message) {
    toast.textContent = message;
    toast.classList.remove('hidden');
    setTimeout(() => {
      toast.classList.add('hidden');
    }, 2800);
  }

  function copyToClipboard(text, successMsg) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text)
        .then(() => showToast(successMsg))
        .catch(() => fallbackCopy(text, successMsg));
    } else {
      fallbackCopy(text, successMsg);
    }
  }

  function fallbackCopy(text, successMsg) {
    const temp = document.createElement('textarea');
    temp.value = text;
    document.body.appendChild(temp);
    temp.select();
    document.execCommand('copy');
    document.body.removeChild(temp);
    showToast(successMsg);
  }
});
