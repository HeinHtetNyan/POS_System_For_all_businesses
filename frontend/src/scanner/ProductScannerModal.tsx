import { useEffect, useRef, useState } from 'react'
import {
  Html5Qrcode,
  Html5QrcodeSupportedFormats,
  Html5QrcodeScannerState,
} from 'html5-qrcode'
import type { CameraCapabilities, CameraDevice } from 'html5-qrcode/esm/camera/core'
import { lookupProductBySku, lookupProductByBarcode } from './useProductScan'
import { Spinner } from '@/components/ui'
import { fmt } from '@/lib/utils'
import type { Product } from '@/shared/types'

const SCAN_FORMATS = [
  Html5QrcodeSupportedFormats.QR_CODE,
  Html5QrcodeSupportedFormats.AZTEC,
  Html5QrcodeSupportedFormats.EAN_13,
  Html5QrcodeSupportedFormats.EAN_8,
  Html5QrcodeSupportedFormats.UPC_A,
  Html5QrcodeSupportedFormats.UPC_E,
  Html5QrcodeSupportedFormats.CODE_128,
  Html5QrcodeSupportedFormats.CODE_39,
  Html5QrcodeSupportedFormats.CODE_93,
  Html5QrcodeSupportedFormats.CODABAR,
  Html5QrcodeSupportedFormats.ITF,
  Html5QrcodeSupportedFormats.PDF_417,
  Html5QrcodeSupportedFormats.DATA_MATRIX,
  Html5QrcodeSupportedFormats.RSS_14,
  Html5QrcodeSupportedFormats.RSS_EXPANDED,
]

const LAST_CAMERA_KEY = 'sawyunpos_scanner_camera'

function loadLastCamera(): string | null {
  try { return localStorage.getItem(LAST_CAMERA_KEY) } catch { return null }
}
function saveLastCamera(id: string) {
  try { localStorage.setItem(LAST_CAMERA_KEY, id) } catch {}
}

// iOS/iPadOS: getCameras() returns every physical lens (wide, ultra-wide, telephoto…).
// Selecting one by lens ID often opens the ultra-wide and shows a black or unusable feed.
// Always use facingMode on iOS so the OS picks the correct primary camera.
function isIOS() {
  return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
}

type ModalState  = 'requesting' | 'active' | 'paused' | 'denied' | 'unsupported'
type ZoomRange   = { min: number; max: number; step: number; current: number }
type ScanFeedback =
  | { type: 'success'; name: string; price: string; format: string | null; quantity: number }
  | { type: 'notfound'; code: string }
  | { type: 'error'; message: string }

const CONTAINER_ID = 'product-scanner-video'

interface ProductScannerModalProps {
  onResult:    (product: Product) => void
  onNotFound?: (code: string) => void  // optional — modal handles feedback inline
  onClose:     () => void
  title?:      string
}

export function ProductScannerModal({
  onResult,
  onNotFound,
  onClose,
  title = 'Scan Product',
}: ProductScannerModalProps) {
  const scannerRef    = useRef<Html5Qrcode | null>(null)
  const processingRef = useRef(false)
  const lastCodeRef   = useRef<string | null>(null)
  const mountedRef    = useRef(true)
  const streamRef     = useRef<MediaStream | null>(null)
  const cbRef         = useRef({ onResult, onNotFound })
  cbRef.current       = { onResult, onNotFound }
  // Tracks how many times each product (by id) has been scanned in this modal session
  const scanCountsRef = useRef<Record<string, number>>({})

  const [modalState, setModalState]         = useState<ModalState>('requesting')
  const [lastScan, setLastScan]             = useState<ScanFeedback | null>(null)
  const [cameras, setCameras]               = useState<CameraDevice[]>([])
  const [activeCameraId, setActiveCameraId] = useState<string | null>(null)
  const [facingMode, setFacingMode]         = useState<'environment' | 'user'>('environment')
  const [torchOn, setTorchOn]               = useState(false)
  const [torchAvailable, setTorchAvailable] = useState(false)
  const [zoomRange, setZoomRange]           = useState<ZoomRange | null>(null)

  async function doStop(scanner: Html5Qrcode) {
    if (mountedRef.current) setTorchOn(false)
    // Capture stream reference before stop() removes the video element from DOM
    const videoEl = document.querySelector(`#${CONTAINER_ID} video`) as HTMLVideoElement | null
    const stream = (videoEl?.srcObject ?? streamRef.current) as MediaStream | null
    try {
      if (scanner.getState() !== Html5QrcodeScannerState.NOT_STARTED) {
        await scanner.stop()
      }
    } catch {}
    // Explicitly release all tracks so the camera indicator turns off on iOS Safari
    try { stream?.getTracks().forEach(t => t.stop()) } catch {}
    try { if (videoEl) videoEl.srcObject = null } catch {}
    streamRef.current = null
  }

  function applyCameraCapabilities(scanner: Html5Qrcode) {
    try {
      const caps: CameraCapabilities = scanner.getRunningTrackCameraCapabilities()
      const torch = caps.torchFeature()
      // html5-qrcode reports isSupported=false on iOS even when torch works.
      // Cross-check with browser's native constraint support as fallback.
      const nativeTorch = !!((navigator.mediaDevices?.getSupportedConstraints?.() ?? {}) as Record<string, boolean>).torch
      setTorchAvailable(torch.isSupported() || nativeTorch)
      const zoom = caps.zoomFeature()
      if (zoom.isSupported()) {
        setZoomRange({ min: zoom.min(), max: zoom.max(), step: zoom.step(), current: zoom.value() ?? zoom.min() })
      } else {
        setZoomRange(null)
      }
    } catch {
      setTorchAvailable(false)
      setZoomRange(null)
    }
  }

  async function startScanning(scanner: Html5Qrcode, cameraIdOrFacing: string | MediaTrackConstraints) {
    if (!mountedRef.current) return
    setModalState('requesting')
    processingRef.current = false
    lastCodeRef.current   = null
    setLastScan(null)
    setTorchOn(false)
    setZoomRange(null)

    try {
      await scanner.start(
        cameraIdOrFacing,
        { fps: 12, qrbox: { width: 300, height: 140 } },
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (decodedText: string, scanResult: any) => {
          if (processingRef.current || decodedText === lastCodeRef.current) return
          const formatName: string | null = scanResult?.result?.format?.formatName ?? null
          try { scanner.pause() } catch {}
          handleCode(scanner, decodedText, formatName)
        },
        () => {},
      )
      if (!mountedRef.current) return
      setModalState('active')

      // Capture stream reference for reliable cleanup (camera indicator turns off on close)
      const vid = document.querySelector(`#${CONTAINER_ID} video`) as HTMLVideoElement | null
      streamRef.current = vid?.srcObject as MediaStream | null

      // Enumerate cameras only on non-iOS — on iOS getCameras() lists every physical lens
      if (!isIOS()) {
        Html5Qrcode.getCameras()
          .then(cams => { if (mountedRef.current) setCameras(cams) })
          .catch(() => {})
      }

      applyCameraCapabilities(scanner)
    } catch (err: unknown) {
      if (!mountedRef.current) return
      const msg = String(err).toLowerCase()
      if (msg.includes('notallowed') || msg.includes('permission')) {
        setModalState('denied')
      } else if (typeof cameraIdOrFacing === 'string') {
        // Remembered camera no longer available — clear and fall back to default rear camera
        localStorage.removeItem(LAST_CAMERA_KEY)
        setActiveCameraId(null)
        startScanning(scanner, { facingMode: 'environment' })
      } else {
        setModalState('unsupported')
      }
    }
  }

  async function handleCode(scanner: Html5Qrcode, code: string, formatName: string | null) {
    processingRef.current = true
    lastCodeRef.current   = code
    if (mountedRef.current) setModalState('paused')

    let result = await lookupProductByBarcode(code)
    if (result.status === 'not_found') result = await lookupProductBySku(code)

    if (!mountedRef.current) return

    let resumeDelay = 2000

    if (result.status === 'found') {
      cbRef.current.onResult(result.product)
      const newCount = (scanCountsRef.current[result.product.id] ?? 0) + 1
      scanCountsRef.current[result.product.id] = newCount
      setLastScan({ type: 'success', name: result.product.name, price: result.product.selling_price ?? '0', format: formatName, quantity: newCount })
      resumeDelay = 500
    } else if (result.status === 'not_found') {
      if (cbRef.current.onNotFound) {
        // Caller handles the "not found" flow (e.g. show an add-product modal)
        cbRef.current.onNotFound(code)
      } else {
        setLastScan({ type: 'notfound', code })
      }
    } else {
      setLastScan({ type: 'error', message: result.message })
    }

    setModalState('active')

    setTimeout(() => {
      if (!mountedRef.current) return
      processingRef.current = false
      lastCodeRef.current   = null
      try { scanner.resume() } catch {}
    }, resumeDelay)
  }

  useEffect(() => {
    mountedRef.current = true
    const scanner = new Html5Qrcode(CONTAINER_ID, {
      verbose: false,
      formatsToSupport: SCAN_FORMATS,
      useBarCodeDetectorIfSupported: true,
    })
    scannerRef.current = scanner

    // Restore last-used camera on non-iOS; iOS always uses facingMode
    const lastCam = isIOS() ? null : loadLastCamera()
    if (lastCam) {
      setActiveCameraId(lastCam)
      startScanning(scanner, lastCam)
    } else {
      startScanning(scanner, { facingMode: 'environment' })
    }

    return () => {
      mountedRef.current = false
      // Synchronously stop tracks so the camera indicator turns off immediately
      try { streamRef.current?.getTracks().forEach(t => t.stop()) } catch {}
      streamRef.current = null
      doStop(scanner)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])

  async function toggleTorch() {
    const scanner = scannerRef.current
    if (!scanner) return
    const next = !torchOn
    let applied = false
    // Try html5-qrcode torch API first
    try {
      const caps: CameraCapabilities = scanner.getRunningTrackCameraCapabilities()
      await caps.torchFeature().apply(next)
      applied = true
    } catch { /* fall through */ }
    // Fallback: apply constraint directly on the video track (works on iOS Safari)
    if (!applied) {
      try {
        const vid = document.querySelector(`#${CONTAINER_ID} video`) as HTMLVideoElement | null
        const track = (vid?.srcObject as MediaStream | null)?.getVideoTracks()[0]
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        if (track) { await track.applyConstraints({ advanced: [{ torch: next } as any] }); applied = true }
      } catch { /* torch not supported on this device */ }
    }
    if (applied) setTorchOn(next)
  }

  async function handleZoomChange(value: number) {
    const scanner = scannerRef.current
    if (!scanner || !zoomRange) return
    try {
      const caps: CameraCapabilities = scanner.getRunningTrackCameraCapabilities()
      await caps.zoomFeature().apply(value)
      setZoomRange(prev => prev ? { ...prev, current: value } : null)
    } catch {}
  }

  async function switchCamera(cameraId: string) {
    const scanner = scannerRef.current
    if (!scanner) return
    setActiveCameraId(cameraId)
    saveLastCamera(cameraId)
    await doStop(scanner)
    await startScanning(scanner, cameraId)
  }

  async function flipCamera() {
    const scanner = scannerRef.current
    if (!scanner) return
    if (!isIOS() && cameras.length > 1 && activeCameraId) {
      const idx  = cameras.findIndex(c => c.id === activeCameraId)
      const next = cameras[(idx + 1) % cameras.length]
      await switchCamera(next.id)
    } else {
      const next: 'environment' | 'user' = facingMode === 'environment' ? 'user' : 'environment'
      setFacingMode(next)
      setActiveCameraId(null)
      await doStop(scanner)
      await startScanning(scanner, { facingMode: next })
    }
  }

  const ios          = isIOS()
  const showDropdown = !ios && cameras.length > 1

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-black">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 bg-zinc-950/90 backdrop-blur-sm border-b border-zinc-800">
        <span className="text-sm font-semibold text-zinc-100">{title}</span>
        <div className="flex items-center gap-2">
          {torchAvailable && (
            <button onClick={toggleTorch}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors ${
                torchOn
                  ? 'bg-amber-500/20 border-amber-500/40 text-amber-400'
                  : 'bg-zinc-800 border-zinc-700 text-zinc-400'
              }`}>
              {torchOn ? '⚡ On' : '⚡ Flash'}
            </button>
          )}
          {showDropdown ? (
            <select
              value={activeCameraId ?? ''}
              onChange={e => switchCamera(e.target.value)}
              className="px-2 py-1.5 rounded-lg text-xs font-medium border bg-zinc-800 border-zinc-700 text-zinc-300 max-w-[120px] truncate">
              {cameras.map(c => (
                <option key={c.id} value={c.id}>{c.label || `Camera ${c.id.slice(0, 4)}`}</option>
              ))}
            </select>
          ) : (
            <button onClick={flipCamera}
              className="px-3 py-1.5 rounded-lg text-xs font-medium border bg-zinc-800 border-zinc-700 text-zinc-400 hover:text-zinc-200 transition-colors">
              Flip
            </button>
          )}
          <button onClick={onClose}
            className="px-3 py-1.5 rounded-lg text-xs font-medium border bg-zinc-800 border-zinc-700 text-zinc-400 hover:text-zinc-200 transition-colors">
            Close
          </button>
        </div>
      </div>

      {/* Viewfinder */}
      <div className="flex-1 relative overflow-hidden bg-black">
        <div id={CONTAINER_ID} className="scanner-video-container" />

        {modalState === 'active' && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div className="w-80 h-36 relative">
              <div className="absolute top-0 left-0 w-10 h-10 border-t-4 border-l-4 border-amber-400 rounded-tl-lg" />
              <div className="absolute top-0 right-0 w-10 h-10 border-t-4 border-r-4 border-amber-400 rounded-tr-lg" />
              <div className="absolute bottom-0 left-0 w-10 h-10 border-b-4 border-l-4 border-amber-400 rounded-bl-lg" />
              <div className="absolute bottom-0 right-0 w-10 h-10 border-b-4 border-r-4 border-amber-400 rounded-br-lg" />
              <div className="absolute inset-x-0 top-0 h-0.5 bg-amber-400/80 animate-scan-line" />
            </div>
          </div>
        )}
        {modalState === 'requesting' && (
          <div className="absolute inset-0 bg-black/80 flex flex-col items-center justify-center gap-3">
            <Spinner size={36} /><p className="text-sm text-zinc-300">Starting camera…</p>
          </div>
        )}
        {modalState === 'paused' && (
          <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
            <Spinner size={28} />
          </div>
        )}
        {modalState === 'denied' && (
          <div className="absolute inset-0 bg-black/90 flex flex-col items-center justify-center gap-4 px-8 text-center">
            <span className="text-4xl">📷</span>
            <p className="text-zinc-100 font-semibold">Camera Access Denied</p>
            <p className="text-zinc-500 text-sm">Allow camera access in your browser settings then try again.</p>
            <button
              onClick={() => scannerRef.current && startScanning(scannerRef.current, { facingMode: 'environment' })}
              className="px-4 py-2 rounded-xl bg-amber-500 text-black font-semibold text-sm">
              Try Again
            </button>
          </div>
        )}
        {modalState === 'unsupported' && (
          <div className="absolute inset-0 bg-black/90 flex flex-col items-center justify-center gap-4 px-8 text-center">
            <span className="text-4xl">⚠️</span>
            <p className="text-zinc-100 font-semibold">Camera Not Available</p>
            <p className="text-zinc-500 text-sm">Use a USB scanner instead.</p>
          </div>
        )}
      </div>

      {/* Footer — scan result or hint + zoom slider */}
      <div className="px-4 py-3 bg-zinc-950/90 border-t border-zinc-800 space-y-2">
        {zoomRange && modalState === 'active' && [1.5, 2.5, 3.5].some(z => z <= zoomRange.max) && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-zinc-500 shrink-0">🔍</span>
            {[1.5, 2.5, 3.5].filter(z => z <= zoomRange.max).map(z => (
              <button
                key={z}
                onClick={() => handleZoomChange(z)}
                className={`px-3 py-1 rounded-lg text-xs font-medium border transition-colors ${
                  Math.abs(zoomRange.current - z) < 0.2
                    ? 'bg-amber-500/20 border-amber-500/40 text-amber-400'
                    : 'bg-zinc-800 border-zinc-700 text-zinc-400 hover:text-zinc-200'
                }`}
              >
                {z}×
              </button>
            ))}
          </div>
        )}

        {lastScan?.type === 'success' ? (
          <div className="flex items-center gap-3 rounded-lg bg-green-500/10 border border-green-500/20 px-3 py-2">
            <div className="w-2 h-2 rounded-full bg-green-400 shrink-0" />
            <p className="flex-1 text-sm font-medium text-green-300 truncate">{lastScan.name}</p>
            <div className="shrink-0 flex items-center gap-2">
              {lastScan.format && (
                <span className="text-xs text-zinc-600 font-mono">{lastScan.format}</span>
              )}
              <span className="text-xs text-zinc-400">×{lastScan.quantity}</span>
              <span className="text-xs font-medium text-zinc-300">{fmt(lastScan.price)}</span>
            </div>
          </div>
        ) : lastScan?.type === 'notfound' ? (
          <div className="flex items-center gap-2 rounded-lg bg-red-500/10 border border-red-500/20 px-3 py-2">
            <div className="w-2 h-2 rounded-full bg-red-400 shrink-0" />
            <p className="text-sm text-red-400 truncate">
              Not found: <span className="font-mono">{lastScan.code}</span>
            </p>
          </div>
        ) : lastScan?.type === 'error' ? (
          <div className="flex items-center gap-2 rounded-lg bg-red-500/10 border border-red-500/20 px-3 py-2">
            <div className="w-2 h-2 rounded-full bg-red-400 shrink-0" />
            <p className="text-sm text-red-400 truncate">Error: {lastScan.message}</p>
          </div>
        ) : (
          <div className="text-center">
            <p className="text-xs text-zinc-500">Point camera at the barcode · Keep it steady and well-lit</p>
            <p className="text-xs text-zinc-600 mt-0.5">Scan items one by one · Press Close when done</p>
          </div>
        )}
      </div>
    </div>
  )
}
