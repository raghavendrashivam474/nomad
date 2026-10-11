// GENERATED FILE — DO NOT EDIT DIRECTLY.
// Embedded JavaScript source for NomadTransport connectivity driver.
// Referenced by ProjectFileServer (Virtual Route) and WebPreviewView (Fallback Injection).

class NomadTransportSource {
  static const String jsContent = r'''
/**
 * NomadTransport — Reusable Local Peer-to-Peer Connectivity Driver
 *
 * Implements the LC-1 D4 Reusable Contract using WebRTC DataChannel.
 * Operates 100% offline via user-mediated SDP token exchange.
 *
 * Architecture:
 * - Direct RTCPeerConnection over LAN/Hotspot (DTLS-SRTP UDP)
 * - Zero cloud / STUN / TURN server dependencies
 * - Bounded message envelope with error framing
 */
class NomadTransport {
  constructor(options = {}) {
    this.options = Object.assign({
      iceGatherTimeoutMs: 2500,
      maxPayloadBytes: 65536 // 64 KB safe threshold
    }, options);

    this._state = 'idle';
    this._localPeerId = 'peer_' + Math.random().toString(36).substring(2, 9);
    this._peerConnection = null;
    this._dataChannel = null;
    this._listeners = new Map();

    this._bindLifecycleHooks();
  }

  get state() {
    return this._state;
  }

  get localPeerId() {
    return this._localPeerId;
  }

  /**
   * Event Subscription
   */
  on(event, callback) {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set());
    }
    this._listeners.get(event).add(callback);
    return () => this.off(event, callback);
  }

  off(event, callback) {
    if (this._listeners.has(event)) {
      this._listeners.get(event).delete(callback);
    }
  }

  _emit(event, ...args) {
    if (this._listeners.has(event)) {
      for (const cb of this._listeners.get(event)) {
        try {
          cb(...args);
        } catch (err) {
          console.error(`[NomadTransport] Error in listener for ${event}:`, err);
        }
      }
    }
  }

  _transitionState(newState) {
    if (this._state === newState) return;
    const oldState = this._state;
    this._state = newState;
    console.log(`[NomadTransport] State: ${oldState} -> ${newState}`);
    this._emit('statechange', newState, oldState);
  }

  /**
   * HOST MODE: Creates an Offer Token (SDP + Host ICE Candidates)
   * @returns {Promise<string>} Base64-encoded Offer Token
   */
  async createHostOffer() {
    this._cleanup();
    this._transitionState('connecting');

    try {
      this._peerConnection = new RTCPeerConnection({ iceServers: [] });
      this._setupPeerConnectionListeners();

      // Host initiates DataChannel
      this._dataChannel = this._peerConnection.createDataChannel('nomad_channel', {
        ordered: true
      });
      this._setupDataChannelListeners(this._dataChannel);

      const offer = await this._peerConnection.createOffer();
      await this._peerConnection.setLocalDescription(offer);

      await this._waitForIceGathering();

      const sessionObj = {
        type: 'offer',
        sdp: this._peerConnection.localDescription.sdp,
        sender: this._localPeerId
      };

      return this._encodeToken(sessionObj);
    } catch (err) {
      this._transitionState('failed');
      this._emit('error', { stage: 'createHostOffer', error: err.message || err });
      throw err;
    }
  }

  /**
   * HOST MODE: Accepts the Answer Token returned by Device B
   * @param {string} answerToken
   */
  async acceptAnswer(answerToken) {
    if (!this._peerConnection || this._state !== 'connecting') {
      throw new Error('Cannot accept answer: PeerConnection not in connecting state');
    }

    try {
      const sessionObj = this._decodeToken(answerToken);
      if (sessionObj.type !== 'answer') {
        throw new Error(`Expected session type "answer", got "${sessionObj.type}"`);
      }

      const remoteDesc = new RTCSessionDescription({
        type: 'answer',
        sdp: sessionObj.sdp
      });

      await this._peerConnection.setRemoteDescription(remoteDesc);
      console.log('[NomadTransport] Host accepted remote answer successfully');
    } catch (err) {
      this._transitionState('failed');
      this._emit('error', { stage: 'acceptAnswer', error: err.message || err });
      throw err;
    }
  }

  /**
   * JOIN MODE: Accepts Host Offer Token and returns an Answer Token
   * @param {string} hostOfferToken
   * @returns {Promise<string>} Base64-encoded Answer Token
   */
  async joinHost(hostOfferToken) {
    this._cleanup();
    this._transitionState('connecting');

    try {
      const sessionObj = this._decodeToken(hostOfferToken);
      if (sessionObj.type !== 'offer') {
        throw new Error(`Expected session type "offer", got "${sessionObj.type}"`);
      }

      this._peerConnection = new RTCPeerConnection({ iceServers: [] });
      this._setupPeerConnectionListeners();

      // Joiner receives DataChannel from peer
      this._peerConnection.ondatachannel = (event) => {
        console.log('[NomadTransport] Received remote DataChannel');
        this._dataChannel = event.channel;
        this._setupDataChannelListeners(this._dataChannel);
      };

      const remoteDesc = new RTCSessionDescription({
        type: 'offer',
        sdp: sessionObj.sdp
      });
      await this._peerConnection.setRemoteDescription(remoteDesc);

      const answer = await this._peerConnection.createAnswer();
      await this._peerConnection.setLocalDescription(answer);

      await this._waitForIceGathering();

      const answerObj = {
        type: 'answer',
        sdp: this._peerConnection.localDescription.sdp,
        sender: this._localPeerId
      };

      return this._encodeToken(answerObj);
    } catch (err) {
      this._transitionState('failed');
      this._emit('error', { stage: 'joinHost', error: err.message || err });
      throw err;
    }
  }

  /**
   * Sends structured payload complying with D4 JSON Envelope
   */
  send(type, payload) {
    if (this._state !== 'connected' || !this._dataChannel || this._dataChannel.readyState !== 'open') {
      console.warn('[NomadTransport] Cannot send message: DataChannel is not open');
      return false;
    }

    const envelope = {
      v: 1,
      id: 'msg_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 6),
      type: type,
      sender: this._localPeerId,
      ts: Date.now(),
      payload: payload
    };

    const raw = JSON.stringify(envelope);
    if (new Blob([raw]).size > this.options.maxPayloadBytes) {
      console.error('[NomadTransport] Payload exceeds safe size ceiling of 64 KB');
      return false;
    }

    this._dataChannel.send(raw);
    return true;
  }

  /**
   * Graceful termination
   */
  disconnect() {
    try {
      this.send('system.close', { reason: 'user_disconnect' });
    } catch (_) {}
    this._cleanup();
    this._transitionState('disconnected');
  }

  _setupPeerConnectionListeners() {
    this._peerConnection.onconnectionstatechange = () => {
      const state = this._peerConnection.connectionState;
      console.log(`[NomadTransport] PeerConnection state: ${state}`);
      if (state === 'failed') {
        this._transitionState('failed');
      } else if (state === 'closed' || state === 'disconnected') {
        this._transitionState('disconnected');
      }
    };

    this._peerConnection.oniceconnectionstatechange = () => {
      console.log(`[NomadTransport] ICE state: ${this._peerConnection.iceConnectionState}`);
      if (this._peerConnection.iceConnectionState === 'failed') {
        this._transitionState('failed');
      }
    };
  }

  _setupDataChannelListeners(channel) {
    channel.onopen = () => {
      console.log('[NomadTransport] DataChannel OPEN');
      this._transitionState('connected');
    };

    channel.onclose = () => {
      console.log('[NomadTransport] DataChannel CLOSED');
      this._transitionState('disconnected');
      this._emit('peer_disconnected');
    };

    channel.onerror = (err) => {
      console.error('[NomadTransport] DataChannel error:', err);
      this._emit('error', { stage: 'datachannel', error: err });
    };

    channel.onmessage = (event) => {
      try {
        const envelope = JSON.parse(event.data);
        if (envelope && envelope.type === 'system.close') {
          this._transitionState('disconnected');
          this._emit('peer_disconnected');
          return;
        }
        this._emit('message', envelope);
      } catch (err) {
        console.warn('[NomadTransport] Dropping malformed payload:', event.data);
        this._emit('error', { stage: 'message_parse', raw: event.data });
      }
    };
  }

  _waitForIceGathering() {
    return new Promise((resolve) => {
      if (this._peerConnection.iceGatheringState === 'complete') {
        resolve();
        return;
      }

      const timer = setTimeout(() => {
        console.log('[NomadTransport] ICE gathering timeout reached; proceeding with current candidates');
        resolve();
      }, this.options.iceGatherTimeoutMs);

      const checkState = () => {
        if (this._peerConnection.iceGatheringState === 'complete') {
          clearTimeout(timer);
          this._peerConnection.removeEventListener('icegatheringstatechange', checkState);
          resolve();
        }
      };

      this._peerConnection.addEventListener('icegatheringstatechange', checkState);
    });
  }

  _encodeToken(obj) {
    return btoa(unescape(encodeURIComponent(JSON.stringify(obj))));
  }

  _decodeToken(tokenStr) {
    const raw = decodeURIComponent(escape(atob(tokenStr.trim())));
    return JSON.parse(raw);
  }

  _cleanup() {
    if (this._dataChannel) {
      try { this._dataChannel.close(); } catch (_) {}
      this._dataChannel = null;
    }
    if (this._peerConnection) {
      try { this._peerConnection.close(); } catch (_) {}
      this._peerConnection = null;
    }
  }

  _bindLifecycleHooks() {
    if (typeof window !== 'undefined') {
      window.addEventListener('beforeunload', () => this.disconnect());
      window.addEventListener('unload', () => this.disconnect());
    }
  }
}

// Global export for vanilla project scripts
if (typeof window !== 'undefined') {
  window.NomadTransport = NomadTransport;
}

''';
}
