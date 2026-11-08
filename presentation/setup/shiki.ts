import { defineShikiSetup } from '@slidev/types'

// Colors of the Godot 4 script editor (default dark theme).
const godot = {
  name: 'godot-editor',
  type: 'dark',
  colors: {
    'editor.background': '#1d2229',
    'editor.foreground': '#cdcfd2',
  },
  tokenColors: [
    { settings: { foreground: '#cdcfd2', background: '#1d2229' } },
    { scope: ['comment', 'punctuation.definition.comment'], settings: { foreground: '#cdcfd280' } },
    { scope: ['keyword', 'storage.type', 'keyword.operator.wordlike', 'constant.language'], settings: { foreground: '#ff7085' } },
    { scope: ['keyword.control', 'keyword.control.flow'], settings: { foreground: '#ff8ccc' } },
    { scope: ['keyword.operator', 'punctuation'], settings: { foreground: '#abc9ff' } },
    { scope: ['entity.name.type.class.builtin'], settings: { foreground: '#42ffc2' } },
    { scope: ['entity.name.type', 'support.type', 'support.class'], settings: { foreground: '#8fffdb' } },
    { scope: ['entity.name.function.decorator', 'meta.annotation'], settings: { foreground: '#ffb373' } },
    { scope: ['entity.name.function'], settings: { foreground: '#66e6ff' } },
    { scope: ['meta.function-call entity.name.function'], settings: { foreground: '#57b3ff' } },
    { scope: ['variable.other.property', 'variable.other.member'], settings: { foreground: '#bce0ff' } },
    { scope: ['variable', 'variable.other'], settings: { foreground: '#cdcfd2' } },
    { scope: ['string', 'string.quoted'], settings: { foreground: '#ffeda1' } },
    { scope: ['constant.numeric'], settings: { foreground: '#a1ffe0' } },
    { scope: ['entity.name.section', 'entity.name.tag'], settings: { foreground: '#57b3ff' } },
    { scope: ['keyword.other.definition', 'support.constant', 'variable.other.key'], settings: { foreground: '#bce0ff' } },
  ],
}

export default defineShikiSetup(() => ({
  themes: {
    dark: godot,
    light: godot,
  },
}))
