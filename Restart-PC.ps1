$computers = Get-Content "\\BR01S-FS\Resources\Scripts\Reiniciar-Update\computer_done.txt"

# Função para executar o scan do Nexus
function RunNexusScan {
    # Comando para executar o scan do Nexus
    Write-Output "Scan do Nexus iniciado..."
    # Adicione o comando para executar o scan do Nexus aqui
}

foreach ($computer in $computers) {
    Write-Output "Verificando se a máquina $computer está online"
    if (Test-Connection -ComputerName $computer -Count 1 -Quiet) {
        Write-Output "Máquina online, acessando via hostname"
        $pssession = New-PSSession -ComputerName $computer -ErrorAction SilentlyContinue
        if (!$pssession) {
            $ip = Test-Connection -ComputerName $computer -Count 1 | Select-Object -ExpandProperty IPv4Address
            Write-Output "Acesso via hostname falhou, tentando via IP"
            $pssession = New-PSSession -ComputerName $ip -ErrorAction SilentlyContinue
        }
        if ($pssession) {
            Write-Output "Conexão estabelecida. Verificando pendências de reinicialização..."
            $lastBootUpTime = Invoke-Command -Session $pssession -ScriptBlock {
                (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            }
            $daysSinceLastReboot = (Get-Date) - $lastBootUpTime
            $pendingReboot = Invoke-Command -Session $pssession -ScriptBlock {
                (Get-Item "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) -ne $null
            }
            if ($pendingReboot -or $daysSinceLastReboot.Days -gt 5) {
                Write-Output "Pendência de reinicialização encontrada ou mais de 5 dias desde o último reinício. Reiniciando a máquina $computer..."
                Invoke-Command -Session $pssession -ScriptBlock {
                    Restart-Computer -Force
                }
                Write-Output "Máquina $computer reiniciada com sucesso"
                # Tratamento após a reinicialização
                # Removendo arquivos temporários e logs antigos
                Invoke-Command -Session $pssession -ScriptBlock {
                    Remove-Item "C:\Temp\*" -Force -Recurse
                }
            } else {
                Write-Output "Sem pendências de reinicialização na máquina $computer"
                RunNexusScan
                # Tratamentos da pasta Temp com os logs, conforme a história do usuário
                # Adicionando a máquina à lista de máquinas atualizadas
                Add-Content "C:\Temp\MachinesUpdated.txt" -Value $computer
            }
            Remove-PSSession $pssession
        } else {
            Write-Output "Falha ao acessar a máquina $computer"
        }
    } else {
        Write-Output "Máquina $computer está offline"
    }
}