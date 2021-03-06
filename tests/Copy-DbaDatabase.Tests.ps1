﻿$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tag "IntegrationTests" {
    BeforeAll {
        $NetworkPath = "C:\temp"
        $random = Get-Random
        $backuprestoredb = "dbatoolsci_backuprestore$random"
        $backuprestoredb2 = "dbatoolsci_backuprestoreother$random"
        $detachattachdb = "dbatoolsci_detachattach$random"
        Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance2, $script:instance3 -Database $backuprestoredb, $detachattachdb

        $server = Connect-DbaInstance -SqlInstance $script:instance3
        $server.Query("CREATE DATABASE $backuprestoredb2; ALTER DATABASE $backuprestoredb2 SET AUTO_CLOSE OFF WITH ROLLBACK IMMEDIATE")

        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $server.Query("CREATE DATABASE $backuprestoredb; ALTER DATABASE $backuprestoredb SET AUTO_CLOSE OFF WITH ROLLBACK IMMEDIATE")
        $server.Query("CREATE DATABASE $detachattachdb; ALTER DATABASE $detachattachdb SET AUTO_CLOSE OFF WITH ROLLBACK IMMEDIATE")
        $server.Query("CREATE DATABASE $backuprestoredb2; ALTER DATABASE $backuprestoredb2 SET AUTO_CLOSE OFF WITH ROLLBACK IMMEDIATE")
        $null = Set-DbaDbOwner -SqlInstance $script:instance2 -Database $backuprestoredb, $detachattachdb -TargetLogin sa
    }
    AfterAll {
        Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance2, $script:instance3 -Database $backuprestoredb, $detachattachdb, $backuprestoredb2
    }

    # if failed Disable-NetFirewallRule -DisplayName 'Core Networking - Group Policy (TCP-Out)'
    Context "Detach Attach" {
        It "Should be success" {
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $detachattachdb -DetachAttach -Reattach -Force #-WarningAction SilentlyContinue
            $results.Status | Should Be "Successful"
        }

        $db1 = Get-DbaDatabase -SqlInstance $script:instance2 -Database $detachattachdb
        $db2 = Get-DbaDatabase -SqlInstance $script:instance3 -Database $detachattachdb

        It "should not be null"  {
            $db1.Name | Should Be $detachattachdb
            $db2.Name | Should Be $detachattachdb
        }

        It "Name, recovery model, and status should match" {
            # Compare its variable
            $db1.Name | Should -Be $db2.Name
            $db1.RecoveryModel | Should -Be $db2.RecoveryModel
            $db1.Status | Should -Be $db2.Status
            $db1.Owner | Should -Be $db2.Owner
        }

        It "Should say skipped" {
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $detachattachdb -DetachAttach -Reattach
            $results.Status | Should be "Skipped"
            $results.Notes | Should be "Already exists"
        }
    }

    Context "Backup restore" {
        Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
        $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -BackupRestore -NetworkShare $NetworkPath 3>$null

        It "copies a database successfully" {
            $results.Name -eq $backuprestoredb
            $results.Status -eq "Successful"
        }

        It "retains its name, recovery model, and status." {
            $dbs = Get-DbaDatabase -SqlInstance $script:instance2, $script:instance3 -Database $backuprestoredb
            $dbs[0].Name -ne $null
            # Compare its variables
            $dbs[0].Name -eq $dbs[1].Name
            $dbs[0].RecoveryModel -eq $dbs[1].RecoveryModel
            $dbs[0].Status -eq $dbs[1].Status
            $dbs[0].Owner -eq $dbs[1].Owner
        }

        # needs regr test that uses $backuprestoredb once #3377 is fixed
        It  "Should say skipped" {
            $result = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb2 -BackupRestore -NetworkShare $NetworkPath 3>$null
            $result.Status | Should be "Skipped"
            $result.Notes | Should be "Already exists"
        }

        # needs regr test once #3377 is fixed
        if (-not $env:appveyor) {
            It "Should overwrite when forced to" {
                #regr test for #3358
                $result = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb2 -BackupRestore -NetworkShare $NetworkPath -Force
                $result.Status | Should be "Successful"
            }
        }
    }
    Context "UseLastBackups - read backup history" {
        BeforeAll {
            Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
            Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance3 -Database $backuprestoredb
        }

        It "copies a database successfully using backup history" {
            # It should already have a backup history by this time
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -BackupRestore -UseLastBackups 3>$null
            $results.Name -eq $backuprestoredb
            $results.Status -eq "Successful"
        }

        It "retains its name, recovery model, and status." {
            $dbs = Get-DbaDatabase -SqlInstance $script:instance2, $script:instance3 -Database $backuprestoredb
            $dbs[0].Name -ne $null
            # Compare its variables
            $dbs[0].Name -eq $dbs[1].Name
            $dbs[0].RecoveryModel -eq $dbs[1].RecoveryModel
            $dbs[0].Status -eq $dbs[1].Status
            $dbs[0].Owner -eq $dbs[1].Owner
        }
    }
    Context "UseLastBackups with -Continue" {
        BeforeAll {
            Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
            Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance3 -Database $backuprestoredb
            #Pre-stage the restore
            $null = Get-DbaBackupHistory -SqlInstance $script:instance2 -Database $backuprestoredb -LastFull | Restore-DbaDatabase -SqlInstance $script:instance3 -DatabaseName $backuprestoredb -NoRecovery 3>$null
            #Run diff now
            $null = Backup-DbaDatabase -SqlInstance $script:instance2 -Database $backuprestoredb -BackupDirectory $NetworkPath -Type Diff
        }

        It "continues the restore over existing database using backup history" {
            # It should already have a backup history (full+diff) by this time
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -BackupRestore -UseLastBackups -Continue 3>$null
            $results.Name -eq $backuprestoredb
            $results.Status -eq "Successful"
        }

        It "retains its name, recovery model, and status." {
            $dbs = Get-DbaDatabase -SqlInstance $script:instance2, $script:instance3 -Database $backuprestoredb
            $dbs[0].Name -ne $null
            # Compare its variables
            $dbs[0].Name -eq $dbs[1].Name
            $dbs[0].RecoveryModel -eq $dbs[1].RecoveryModel
            $dbs[0].Status -eq $dbs[1].Status
            $dbs[0].Owner -eq $dbs[1].Owner
        }
    }
    Context "Copying with renames using backup/restore" {
        BeforeAll {
            Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
            Get-DbaDatabase -SqlInstance $script:instance3 -ExcludeAllSystemDb | Remove-DbaDatabase -Confirm:$false
        }
        AfterAll {
            Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
            Get-DbaDatabase -SqlInstance $script:instance3 -ExcludeAllSystemDb | Remove-DbaDatabase -Confirm:$false
        }
        It "Should have renamed a single db"{
            $newname = "copy$(Get-Random)"
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -BackupRestore -NetworkShare $NetworkPath -NewName $newname
            $results[0].DestinationDatabase | Should -Be $newname
            $files  = Get-DbaDbFile -Sqlinstance $script:instance3 -Database $newname
            ($files.PhysicalName -like  "*$newname*").count | Should -Be $files.count
        }

        It "Should warn if trying to rename and prefix" {
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -BackupRestore -NetworkShare $NetworkPath -NewName $newname -prefix pre -WarningVariable warnvar
            $warnvar | Should -BeLike "*NewName and Prefix are exclusive options, cannot specify both"

        }

        It "Should prefix databasename and files"{
            $prefix = "da$(Get-Random)"
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -BackupRestore -NetworkShare $NetworkPath -Prefix $prefix
            $results[0].DestinationDatabase | Should -Be "$prefix$backuprestoredb"
            $files  = Get-DbaDbFile -Sqlinstance $script:instance3 -Database "$prefix$backuprestoredb"
            ($files.PhysicalName -like  "*$prefix$backuprestoredb*").count | Should -Be $files.count
        }
    }

    Context "Copying with renames using detachattach" {
        BeforeAll {
            Get-DbaProcess -SqlInstance $script:instance2, $script:instance3 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess -WarningAction SilentlyContinue
            Remove-DbaDatabase -Confirm:$false -SqlInstance $script:instance3 -Database $backuprestoredb
        }
        It "Should have renamed a single db"{
            $newname = "copy$(Get-Random)"
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -DetachAttach -NewName $newname -Reattach
            $results[0].DestinationDatabase | Should -Be $newname
            $files  = Get-DbaDbFile -Sqlinstance $script:instance3 -Database $newname
            ($files.PhysicalName -like  "*$newname*").count | Should -Be $files.count
        }

        It "Should prefix databasename and files"{
            $prefix = "copy$(Get-Random)"
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb -DetachAttach -Reattach -Prefix $prefix
            $results[0].DestinationDatabase | Should -Be "$prefix$backuprestoredb"
            $files  = Get-DbaDbFile -Sqlinstance $script:instance3 -Database "$prefix$backuprestoredb"
            ($files.PhysicalName -like  "*$prefix$backuprestoredb*").count | Should -Be $files.count
        }

        $null = Restore-DbaDatabase -SqlInstance $script:instance2 -path $script:appveyorlabrepo\RestoreTimeClean -useDestinationDefaultDirectories
        It "Should warn and exit if newname and >1 db specified"{
            $prefix = "copy$(Get-Random)"
            $results = Copy-DbaDatabase -Source $script:instance2 -Destination $script:instance3 -Database $backuprestoredb, RestoreTimeClean -DetachAttach -Reattach -NewName warn -WarningVariable warnvar
            $Warnvar | Should -BeLike "*Cannot use NewName when copying multiple databases"
        }
    }
}
