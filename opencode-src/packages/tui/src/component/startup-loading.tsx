import { createEffect, createMemo, createSignal, onCleanup, Show, onMount } from "solid-js"
import { useTheme } from "../context/theme"
import { Logo } from "./logo"

const PROGRESS_BAR_WIDTH = 40
const FULL_BLOCK = "█"
const EMPTY_BLOCK = "░"

function ProgressBar(props: { progress: () => number; color: () => any; dimColor?: () => any }) {
  const filled = () => Math.floor((props.progress() / 100) * PROGRESS_BAR_WIDTH)
  const empty = () => PROGRESS_BAR_WIDTH - filled()
  const percent = () => Math.floor(props.progress())

  return (
    <box flexDirection="row" alignItems="center" gap={1}>
      <text fg={props.color()} selectable={false}>
        {FULL_BLOCK.repeat(filled())}
      </text>
      <text fg={props.dimColor ? props.dimColor() : props.color()} selectable={false}>
        {EMPTY_BLOCK.repeat(empty())}
      </text>
      <text fg={props.color()} selectable={false}>
        {" "}{percent()}%
      </text>
    </box>
  )
}

export function StartupLoading(props: { ready: () => boolean }) {
  const theme = useTheme().theme
  const [show, setShow] = createSignal(false)
  const [progress, setProgress] = createSignal(0)
  const text = createMemo(() => (props.ready() ? "Finalizando..." : "Carregando plugins..."))
  let wait: NodeJS.Timeout | undefined
  let hold: NodeJS.Timeout | undefined
  let progressInterval: NodeJS.Timeout | undefined
  let startTime = 0
  let stamp = 0

  const startProgressAnimation = () => {
    startTime = Date.now()
    setProgress(0)
    progressInterval = setInterval(() => {
      const elapsed = Date.now() - startTime
      // Simulate progress: fast at start, slows down, caps at 90%
      const simulated = Math.min(90, 100 * (1 - Math.exp(-elapsed / 4000)))
      setProgress(simulated)
    }, 100)
  }

  const stopProgressAnimation = () => {
    if (progressInterval) {
      clearInterval(progressInterval)
      progressInterval = undefined
    }
    // Quick completion to 100%
    setProgress(100)
  }

  createEffect(() => {
    if (props.ready()) {
      if (wait) {
        clearTimeout(wait)
        wait = undefined
      }
      if (!show()) return
      if (hold) return

      stopProgressAnimation()

      const left = 3000 - (Date.now() - stamp)
      if (left <= 0) {
        setShow(false)
        return
      }

      hold = setTimeout(() => {
        hold = undefined
        setShow(false)
      }, left).unref()
      return
    }

    if (hold) {
      clearTimeout(hold)
      hold = undefined
    }
    if (show()) return
    if (wait) return

    wait = setTimeout(() => {
      wait = undefined
      stamp = Date.now()
      setShow(true)
      startProgressAnimation()
    }, 500).unref()
  })

  onCleanup(() => {
    if (wait) clearTimeout(wait)
    if (hold) clearTimeout(hold)
    if (progressInterval) clearInterval(progressInterval)
  })

  return (
    <Show when={show()}>
      <box
        position="absolute"
        zIndex={5000}
        top={0}
        bottom={0}
        left={0}
        right={0}
        justifyContent="center"
        alignItems="center"
        flexDirection="column"
      >
        <Logo />
        <box marginTop={1} flexDirection="column" alignItems="center" gap={0}>
          <ProgressBar progress={progress} color={() => theme.textMuted} dimColor={() => theme.textMuted} />
          <box marginTop={0}>
            <text fg={theme.textMuted} selectable={false}>
              {text()}
            </text>
          </box>
        </box>
      </box>
    </Show>
  )
}
