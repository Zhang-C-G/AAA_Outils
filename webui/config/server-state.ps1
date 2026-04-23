$stateRoot = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'server_state'

. (Join-Path $stateRoot 'capture.ps1')
. (Join-Path $stateRoot 'assistant.ps1')
. (Join-Path $stateRoot 'config.ps1')
