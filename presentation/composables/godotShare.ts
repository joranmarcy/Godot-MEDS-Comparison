import { ref, shallowRef } from 'vue'

// Window capture is per tab, so the presenter tab streams it to the audience
// tab(s) through a local WebRTC connection, signalled over BroadcastChannel.
// The capture stays alive while hidden, so the screen is picked once, then
// shown and hidden without picking it again.
// Capture a whole screen rather than the Godot window: the running game,
// even when embedded in the editor's Game tab, is a separate OS window that
// window capture leaves out.

type Message =
  | { type: 'hello' | 'start' | 'stop', from: string }
  | { type: 'visibility', from: string, visible: boolean }
  | { type: 'offer', from: string, to: string, sdp: RTCSessionDescriptionInit, visible: boolean }
  | { type: 'answer', from: string, to: string, sdp: RTCSessionDescriptionInit }
  | { type: 'ice', from: string, to: string, candidate: RTCIceCandidateInit }

interface Peer { pc: RTCPeerConnection, from: string, ready: Promise<unknown> }

const id = Math.random().toString(36).slice(2)
const channel = typeof BroadcastChannel === 'undefined' ? null : new BroadcastChannel('meds-godot-share')

export const shareStream = shallowRef<MediaStream | null>(null)
export const isCapturing = ref(false)
export const isShareVisible = ref(false)

let local: MediaStream | null = null
const senders = new Map<string, Peer>()
let receiver: Peer | null = null

function post(message: Message) {
  channel?.postMessage(message)
}

function createPeer(remote: string) {
  const pc = new RTCPeerConnection()
  pc.onicecandidate = (e) => {
    if (e.candidate)
      post({ type: 'ice', from: id, to: remote, candidate: e.candidate.toJSON() })
  }
  return pc
}

function connectViewer(viewer: string) {
  if (!local)
    return
  senders.get(viewer)?.pc.close()
  const pc = createPeer(viewer)
  local.getTracks().forEach(track => pc.addTrack(track, local!))
  const ready = (async () => {
    await pc.setLocalDescription(await pc.createOffer())
    post({ type: 'offer', from: id, to: viewer, sdp: pc.localDescription!.toJSON(), visible: isShareVisible.value })
  })()
  senders.set(viewer, { pc, from: viewer, ready })
}

function closeReceiver() {
  receiver?.pc.close()
  receiver = null
  if (!local) {
    shareStream.value = null
    isShareVisible.value = false
  }
}

function acceptOffer(from: string, sdp: RTCSessionDescriptionInit, visible: boolean) {
  closeReceiver()
  isShareVisible.value = visible
  const pc = createPeer(from)
  pc.ontrack = e => shareStream.value = e.streams[0] ?? new MediaStream([e.track])
  const ready = (async () => {
    await pc.setRemoteDescription(sdp)
    await pc.setLocalDescription(await pc.createAnswer())
    post({ type: 'answer', from: id, to: from, sdp: pc.localDescription!.toJSON() })
  })()
  receiver = { pc, from, ready }
}

function enqueue(peer: Peer, step: () => Promise<unknown>) {
  peer.ready = peer.ready.then(step).catch(e => console.warn('[godot-share]', e))
}

if (channel) {
  channel.onmessage = ({ data }: MessageEvent<Message>) => {
    if (data.from === id || ('to' in data && data.to !== id))
      return
    switch (data.type) {
      case 'start':
        post({ type: 'hello', from: id })
        break
      case 'hello':
        connectViewer(data.from)
        break
      case 'stop':
        if (receiver?.from === data.from)
          closeReceiver()
        break
      case 'visibility':
        if (receiver?.from === data.from)
          isShareVisible.value = data.visible
        break
      case 'offer':
        acceptOffer(data.from, data.sdp, data.visible)
        break
      case 'answer': {
        const sender = senders.get(data.from)
        if (sender)
          enqueue(sender, () => sender.pc.setRemoteDescription(data.sdp))
        break
      }
      case 'ice': {
        const peer = senders.get(data.from) ?? (receiver?.from === data.from ? receiver : null)
        if (peer)
          enqueue(peer, () => peer.pc.addIceCandidate(data.candidate))
        break
      }
    }
  }
  // An audience tab opened while sharing joins the running share.
  post({ type: 'hello', from: id })
}

export function setShareVisible(visible: boolean) {
  if (!local)
    return
  isShareVisible.value = visible
  post({ type: 'visibility', from: id, visible })
}

export async function startShare() {
  if (local)
    return
  local = await navigator.mediaDevices.getDisplayMedia({
    video: { displaySurface: 'monitor', frameRate: 30 },
    audio: false,
    // Chrome hint: hide this tab from the picker.
    selfBrowserSurface: 'exclude',
    preferCurrentTab: false,
  } as DisplayMediaStreamOptions)
  local.getVideoTracks()[0].addEventListener('ended', stopShare)
  closeReceiver()
  shareStream.value = local
  isShareVisible.value = true
  isCapturing.value = true
  post({ type: 'start', from: id })
}

export function stopShare() {
  local?.getTracks().forEach(track => track.stop())
  local = null
  senders.forEach(({ pc }) => pc.close())
  senders.clear()
  shareStream.value = null
  isShareVisible.value = false
  isCapturing.value = false
  post({ type: 'stop', from: id })
}

export function toggleShare() {
  if (!local)
    return startShare()
  setShareVisible(!isShareVisible.value)
}
