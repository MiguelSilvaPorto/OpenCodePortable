import { Prompt, type PromptRef } from "../component/prompt"
import { createEffect, createMemo, createSignal, onMount, onCleanup, For } from "solid-js"
import { Logo } from "../component/logo"
import { useSync } from "../context/sync"
import { Toast } from "../ui/toast"
import { useArgs } from "../context/args"
import { useRouteData } from "../context/route"
import { usePromptRef } from "../context/prompt"
import { useLocal } from "../context/local"
import { usePluginRuntime } from "../plugin/runtime"
import { useEditorContext } from "../context/editor"
import { useTerminalDimensions } from "@opentui/solid"
import { useTuiConfig } from "../config"
import { HomeSessionDestinationProvider } from "./home/session-destination"

let once = false
const placeholder = {
  normal: ["Fix a TODO in the codebase", "What is the tech stack of this project?", "Fix broken tests"],
  shell: ["ls -la", "git status", "pwd"],
}

type Star = {
  id: number
  x: number
  y: number
  speed: number
  char: string
  color: string
}

function FallingStars() {
  const dimensions = useTerminalDimensions()
  const [stars, setStars] = createSignal<Star[]>([])

  onMount(() => {
    const initialStars: Star[] = []
    const chars = [".", "+", "*", "★", "☆"]
    const colors = ["#4B5563", "#6B7280", "#9CA3AF", "#D1D5DB", "#E5E7EB", "#F3F4F6", "#60A5FA", "#34D399", "#FBBF24"]
    
    for (let i = 0; i < 35; i++) {
      initialStars.push({
        id: i,
        x: Math.random() * dimensions().width,
        y: Math.random() * dimensions().height,
        speed: Math.random() * 0.4 + 0.1,
        char: chars[Math.floor(Math.random() * chars.length)],
        color: colors[Math.floor(Math.random() * colors.length)]
      })
    }
    setStars(initialStars)

    const interval = setInterval(() => {
      const w = dimensions().width
      const h = dimensions().height
      if (w <= 0 || h <= 0) return

      setStars(prev => prev.map(star => {
        let newY = star.y + star.speed
        if (newY >= h) {
          return {
            ...star,
            x: Math.random() * w,
            y: 0,
            speed: Math.random() * 0.4 + 0.1,
            char: chars[Math.floor(Math.random() * chars.length)]
          }
        }
        return { ...star, y: newY }
      }))
    }, 120)

    onCleanup(() => clearInterval(interval))
  })

  return (
    <box position="absolute" top={0} left={0} width={dimensions().width} height={dimensions().height} zIndex={0}>
      <For each={stars()}>
        {(star) => (
          <box
            position="absolute"
            left={Math.floor(star.x)}
            top={Math.floor(star.y)}
          >
            <text fg={star.color}>{star.char}</text>
          </box>
        )}
      </For>
    </box>
  )
}

export function Home() {
  const pluginRuntime = usePluginRuntime()
  const sync = useSync()
  const route = useRouteData("home")
  const promptRef = usePromptRef()
  const [ref, setRef] = createSignal<PromptRef | undefined>()
  const args = useArgs()
  const local = useLocal()
  const editor = useEditorContext()
  const dimensions = useTerminalDimensions()
  const tuiConfig = useTuiConfig()
  const promptMaxWidth = createMemo(() => {
    const configured = tuiConfig.prompt?.max_width
    if (configured === "auto") return Math.max(75, Math.floor(dimensions().width * 0.7))
    return configured ?? 75
  })
  let sent = false

  onMount(() => {
    editor.clearSelection()
  })

  const bind = (r: PromptRef | undefined) => {
    setRef(r)
    promptRef.set(r)
    if (once || !r) return
    if (route.prompt) {
      r.set(route.prompt)
      once = true
      return
    }
    if (!args.prompt) return
    r.set({ input: args.prompt, parts: [] })
    once = true
  }

  // Wait for sync and model store to be ready before auto-submitting --prompt
  createEffect(() => {
    const r = ref()
    if (sent) return
    if (!r) return
    if (!sync.ready || !local.model.ready) return
    if (!args.prompt) return
    if (r.current.input !== args.prompt) return
    sent = true
    r.submit()
  })

  return (
    <HomeSessionDestinationProvider>
      <FallingStars />
      <box flexGrow={1} alignItems="center" paddingLeft={2} paddingRight={2} zIndex={10}>
        <box flexGrow={1} minHeight={0} />
        <box height={4} minHeight={0} flexShrink={1} />
        <box flexShrink={0}>
          <pluginRuntime.Slot name="home_logo" mode="replace">
            <Logo />
          </pluginRuntime.Slot>
        </box>
        <box height={1} minHeight={0} flexShrink={1} />
        <box width="100%" maxWidth={promptMaxWidth()} zIndex={1000} paddingTop={1} flexShrink={0}>
          <pluginRuntime.Slot name="home_prompt" mode="replace" ref={bind}>
            <Prompt ref={bind} right={<pluginRuntime.Slot name="home_prompt_right" />} placeholders={placeholder} />
          </pluginRuntime.Slot>
        </box>
        <pluginRuntime.Slot name="home_bottom" />
        <box flexGrow={1} minHeight={0} />
        <Toast />
      </box>
      <box width="100%" flexShrink={0}>
        <pluginRuntime.Slot name="home_footer" mode="single_winner" />
      </box>
    </HomeSessionDestinationProvider>
  )
}
