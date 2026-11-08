import { defineMermaidSetup } from '@slidev/types'

export default defineMermaidSetup(() => ({
  theme: 'base',
  fontFamily: '"Inter Variable", sans-serif',
  themeVariables: {
    darkMode: true,
    background: '#202326',
    fontFamily: '"Inter Variable", sans-serif',
    fontSize: '16px',
    primaryColor: '#333639',
    primaryTextColor: '#e0e2e4',
    primaryBorderColor: '#55595e',
    secondaryColor: '#25282b',
    tertiaryColor: '#25282b',
    lineColor: '#8b9bb4',
    textColor: '#e0e2e4',
    edgeLabelBackground: '#25282b',
  },
}))
