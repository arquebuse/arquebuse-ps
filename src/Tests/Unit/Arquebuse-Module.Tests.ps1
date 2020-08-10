#-------------------------------------------------------------------------
Set-Location -Path $PSScriptRoot
#-------------------------------------------------------------------------
$ModuleName = 'Arquebuse'
$PathToManifest = [System.IO.Path]::Combine('..', '..', $ModuleName, "$ModuleName.psd1")
$PathToModule = [System.IO.Path]::Combine('..', '..', $ModuleName, "$ModuleName.psm1")
#-------------------------------------------------------------------------
Describe 'Module Tests' -Tag Unit {
    Context "Module Tests" {
        It 'Passes Test-ModuleManifest' {
            Test-ModuleManifest -Path $PathToManifest | Should Not BeNullOrEmpty
            $? | Should Be $true
        }
        It 'root module Arquebuse.psm1 should exist' {
            $PathToModule | Should Exist
            $? | Should Be $true
        }
        It 'manifest should contain Arquebuse.psm1' {
            $PathToManifest |
                Should -FileContentMatchExactly "Arquebuse.psm1"
        }
    }
}
