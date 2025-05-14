# AWS CLI v2とSSM Pluginのインストール・管理スクリプト
# このスクリプトはAWS CLI v2とSession Manager Pluginのインストール、更新、アンインストールを自動化します

# 色の定義
$Colors = @{
    Red = 'Red'
    Green = 'Green'
    Yellow = 'Yellow'
    Blue = 'Cyan'
}

# ログ出力関数
function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
}

# 管理者権限の確認
function Test-AdminPrivileges {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# AWS CLIがインストールされているか確認する関数
function Test-AwsCli {
    Write-LogInfo "AWS CLIの存在を確認しています..."
    
    try {
        $version = aws --version 2>&1
        Write-LogSuccess "AWS CLI がインストールされています: $version"
        
        # バージョン2かどうかを確認
        if ($version -match "aws-cli/2") {
            Write-LogInfo "AWS CLI v2が検出されました"
            return 0
        }
        else {
            Write-LogWarning "AWS CLI v1が検出されました。v2へのアップグレードを推奨します"
            return 2
        }
    }
    catch {
        Write-LogWarning "AWS CLI がインストールされていません"
        return 1
    }
}

# AWS CLIをインストールする関数
function Install-AwsCli {
    param(
        [switch]$DirectInstall
    )
    
    Write-LogInfo "Windows用のAWS CLI v2をインストールしています..."
    
    # システム要件の確認
    if ([Environment]::Is64BitOperatingSystem -eq $false) {
        Write-LogError "AWS CLI v2は64ビットWindowsのみをサポートしています"
        return 1
    }
    
    try {
        if ($DirectInstall) {
            # msiexecを使用して直接インストール
            Write-LogInfo "msiexecを使用して直接インストールを実行しています..."
            Start-Process msiexec.exe -ArgumentList "/i https://awscli.amazonaws.com/AWSCLIV2.msi /qn /norestart" -Wait -NoNewWindow
        }
        else {
            # 一時ディレクトリの作成
            $tempDir = [System.IO.Path]::GetTempPath()
            $installerPath = Join-Path $tempDir "AWSCLIV2.msi"
            
            # インストーラーのダウンロード
            Write-LogInfo "AWS CLI v2をダウンロードしています..."
            Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile $installerPath
            
            # インストーラーの実行
            Write-LogInfo "AWS CLI v2をインストールしています..."
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn /norestart" -Wait -NoNewWindow
            
            # 一時ファイルの削除
            if (Test-Path $installerPath) {
                Remove-Item $installerPath -Force
            }
        }
        
        # インストールの確認
        Write-LogInfo "インストールを確認しています..."
        
        # PATHの更新を反映
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # コマンドの実行確認
        $result = Test-AwsCli
        if ($result -eq 0) {
            Write-LogSuccess "AWS CLI v2のインストールが完了しました"
            
            # バージョンの表示
            try {
                $version = aws --version 2>&1
                Write-LogInfo "インストールされたバージョン: $version"
            }
            catch {
                Write-LogWarning "バージョン情報の取得に失敗しました"
            }
            
            # PATHの確認
            if ((Get-Command aws -ErrorAction SilentlyContinue).Path) {
                Write-LogInfo "AWS CLIは正しくPATHに追加されています"
            }
            else {
                Write-LogWarning "AWS CLIがPATHに追加されていない可能性があります"
                Write-LogInfo "コマンドプロンプトを再起動して再度確認してください"
            }
            
            return 0
        }
        else {
            Write-LogError "AWS CLI v2のインストールに失敗しました"
            Write-LogInfo "詳細については、以下のドキュメントを参照してください:"
            Write-LogInfo "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            return 1
        }
    }
    catch {
        Write-LogError "インストール中にエラーが発生しました: $_"
        return 1
    }
}

# AWS CLIをアンインストールする関数
function Uninstall-AwsCli {
    Write-LogInfo "AWS CLI v2をアンインストールしています..."
    
    try {
        # アンインストールコマンドの実行
        $app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "AWS Command Line Interface v2" }
        if ($app) {
            $app.Uninstall()
            Write-LogSuccess "AWS CLI v2のアンインストールが完了しました"
            return 0
        }
        else {
            Write-LogWarning "AWS CLIのインストールが見つかりません"
            return 1
        }
    }
    catch {
        Write-LogError "アンインストール中にエラーが発生しました: $_"
        return 1
    }
}

# AWS CLIを更新する関数
function Update-AwsCli {
    Write-LogInfo "AWS CLI v2を更新しています..."
    
    # 現在のバージョンを確認
    $currentVersion = $null
    try {
        $currentVersion = aws --version 2>&1
        Write-LogInfo "現在のバージョン: $currentVersion"
    }
    catch {}
    
    # アンインストールと再インストールを実行
    if ((Uninstall-AwsCli) -ne 0) {
        Write-LogError "アンインストールに失敗したため、更新を中止します"
        return 1
    }
    
    if ((Install-AwsCli) -ne 0) {
        Write-LogError "再インストールに失敗しました"
        return 1
    }
    
    # 新しいバージョンを確認
    try {
        $newVersion = aws --version 2>&1
        Write-LogSuccess "AWS CLI v2を更新しました: $currentVersion → $newVersion"
        return 0
    }
    catch {
        Write-LogError "更新後のバージョン確認に失敗しました"
        return 1
    }
}

# SSM Pluginがインストールされているか確認する関数
function Test-SsmPlugin {
    Write-LogInfo "SSM Pluginの存在を確認しています..."
    
    try {
        $version = session-manager-plugin --version 2>&1
        Write-LogSuccess "SSM Plugin がインストールされています: $version"
        return 0
    }
    catch {
        Write-LogWarning "SSM Plugin がインストールされていません"
        return 1
    }
}

# SSM Pluginをインストールする関数
function Install-SsmPlugin {
    param(
        [switch]$UseZip
    )
    
    Write-LogInfo "Windows用のSSM Pluginをインストールしています..."
    
    # PowerShellバージョンの確認
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-LogWarning "Windows PowerShell 5以降を推奨しています。現在のバージョン: $($psVersion.ToString())"
    }
    
    # 一時ディレクトリの作成
    $tempDir = [System.IO.Path]::GetTempPath()
    
    try {
        if ($UseZip) {
            # ZIP形式のインストーラーを使用
            $zipPath = Join-Path $tempDir "SessionManagerPlugin.zip"
            $extractPath = Join-Path $tempDir "SessionManagerPlugin"
            
            # ZIPファイルのダウンロード
            Write-LogInfo "SSM Plugin (ZIP形式) をダウンロードしています..."
            Invoke-WebRequest -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPlugin.zip" -OutFile $zipPath
            
            # ZIPファイルの解凍
            Write-LogInfo "ZIPファイルを解凍しています..."
            if (Test-Path $extractPath) {
                Remove-Item -Path $extractPath -Recurse -Force
            }
            Expand-Archive -Path $zipPath -DestinationPath $extractPath
            
            # インストールディレクトリの作成
            $installDir = "$env:ProgramFiles\Amazon\SessionManagerPlugin\bin"
            if (-not (Test-Path $installDir)) {
                New-Item -Path $installDir -ItemType Directory -Force | Out-Null
            }
            
            # ファイルのコピー
            Write-LogInfo "ファイルをインストールディレクトリにコピーしています..."
            Copy-Item -Path "$extractPath\*" -Destination $installDir -Recurse -Force
            
            # PATHへの追加確認
            $path = [Environment]::GetEnvironmentVariable("PATH", "Machine")
            if ($path -notlike "*$installDir*") {
                Write-LogInfo "PATHにインストールディレクトリを追加しています..."
                [Environment]::SetEnvironmentVariable("PATH", "$path;$installDir", "Machine")
            }
        }
        else {
            # EXE形式のインストーラーを使用
            $installerPath = Join-Path $tempDir "SessionManagerPluginSetup.exe"
            
            # インストーラーのダウンロード
            Write-LogInfo "SSM Plugin (EXE形式) をダウンロードしています..."
            Invoke-WebRequest -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -OutFile $installerPath
            
            # インストーラーの実行
            Write-LogInfo "SSM Pluginをインストールしています..."
            Start-Process $installerPath -ArgumentList "/quiet /norestart" -Wait
        }
        
        # インストールの確認
        Write-LogInfo "インストールを確認しています..."
        
        # PATHの更新を反映
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # インストールディレクトリの確認
        $installDir = "$env:ProgramFiles\Amazon\SessionManagerPlugin\bin"
        if (Test-Path "$installDir\session-manager-plugin.exe") {
            Write-LogSuccess "SSM Pluginがインストールディレクトリに存在します"
        }
        else {
            Write-LogWarning "SSM Pluginがインストールディレクトリに見つかりません"
        }
        
        # コマンドの実行確認
        $result = Test-SsmPlugin
        if ($result -eq 0) {
            Write-LogSuccess "SSM Pluginのインストールが完了しました"
            Write-LogInfo "インストールディレクトリ: $installDir"
            return 0
        }
        else {
            Write-LogError "SSM Pluginのインストールに失敗しました"
            Write-LogInfo "PATHを確認してください: $installDir"
            return 1
        }
    }
    catch {
        Write-LogError "インストール中にエラーが発生しました: $_"
        return 1
    }
    finally {
        # 一時ファイルの削除
        if ($UseZip) {
            if (Test-Path $zipPath) {
                Remove-Item -Path $zipPath -Force
            }
            if (Test-Path $extractPath) {
                Remove-Item -Path $extractPath -Recurse -Force
            }
        }
        else {
            if (Test-Path $installerPath) {
                Remove-Item -Path $installerPath -Force
            }
        }
    }
}

# SSM Pluginをアンインストールする関数
function Uninstall-SsmPlugin {
    Write-LogInfo "SSM Pluginをアンインストールしています..."
    
    try {
        # アンインストールコマンドの実行
        $app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "Session Manager Plugin" }
        if ($app) {
            $app.Uninstall()
            Write-LogSuccess "SSM Pluginのアンインストールが完了しました"
            return 0
        }
        else {
            Write-LogWarning "SSM Pluginのインストールが見つかりません"
            return 1
        }
    }
    catch {
        Write-LogError "アンインストール中にエラーが発生しました: $_"
        return 1
    }
}

# SSM Pluginを更新する関数
function Update-SsmPlugin {
    Write-LogInfo "SSM Pluginを更新しています..."
    
    # 現在のバージョンを確認
    $currentVersion = $null
    try {
        $currentVersion = session-manager-plugin --version 2>&1
        Write-LogInfo "現在のバージョン: $currentVersion"
    }
    catch {}
    
    # アンインストールと再インストールを実行
    if ((Uninstall-SsmPlugin) -ne 0) {
        Write-LogError "アンインストールに失敗したため、更新を中止します"
        return 1
    }
    
    if ((Install-SsmPlugin) -ne 0) {
        Write-LogError "再インストールに失敗しました"
        return 1
    }
    
    # 新しいバージョンを確認
    try {
        $newVersion = session-manager-plugin --version 2>&1
        Write-LogSuccess "SSM Pluginを更新しました: $currentVersion → $newVersion"
        return 0
    }
    catch {
        Write-LogError "更新後のバージョン確認に失敗しました"
        return 1
    }
}

# 両方のツールをインストールする関数
function Install-AllTools {
    param(
        [switch]$UseZipForPlugin
    )
    
    Write-LogInfo "AWS CLI v2とSSM Pluginをインストールしています..."
    
    $cliInstalled = $false
    $pluginInstalled = $false
    
    # AWS CLIのインストール
    if ((Test-AwsCli) -ne 0) {
        if ((Install-AwsCli) -eq 0) {
            $cliInstalled = $true
        }
        else {
            Write-LogError "AWS CLI v2のインストールに失敗しました"
        }
    }
    else {
        Write-LogInfo "AWS CLI v2は既にインストールされています"
        $cliInstalled = $true
    }
    
    # SSM Pluginのインストール
    if ((Test-SsmPlugin) -ne 0) {
        if ((Install-SsmPlugin -UseZip:$UseZipForPlugin) -eq 0) {
            $pluginInstalled = $true
        }
        else {
            Write-LogError "SSM Pluginのインストールに失敗しました"
        }
    }
    else {
        Write-LogInfo "SSM Pluginは既にインストールされています"
        $pluginInstalled = $true
    }
    
    # 結果の表示
    if ($cliInstalled -and $pluginInstalled) {
        Write-LogSuccess "AWS CLI v2とSSM Pluginのインストールが完了しました"
        return 0
    }
    elseif ($cliInstalled) {
        Write-LogWarning "AWS CLI v2のインストールは成功しましたが、SSM Pluginのインストールに失敗しました"
        return 1
    }
    elseif ($pluginInstalled) {
        Write-LogWarning "SSM Pluginのインストールは成功しましたが、AWS CLI v2のインストールに失敗しました"
        return 1
    }
    else {
        Write-LogError "AWS CLI v2とSSM Pluginのインストールに失敗しました"
        return 1
    }
}

# 両方のツールを更新する関数
function Update-AllTools {
    Write-LogInfo "AWS CLI v2とSSM Pluginを更新しています..."
    
    $cliUpdated = $false
    $pluginUpdated = $false
    
    # AWS CLIの更新
    if ((Update-AwsCli) -eq 0) {
        $cliUpdated = $true
    }
    else {
        Write-LogError "AWS CLI v2の更新に失敗しました"
    }
    
    # SSM Pluginの更新
    if ((Update-SsmPlugin) -eq 0) {
        $pluginUpdated = $true
    }
    else {
        Write-LogError "SSM Pluginの更新に失敗しました"
    }
    
    # 結果の表示
    if ($cliUpdated -and $pluginUpdated) {
        Write-LogSuccess "AWS CLI v2とSSM Pluginの更新が完了しました"
        return 0
    }
    elseif ($cliUpdated) {
        Write-LogWarning "AWS CLI v2の更新は成功しましたが、SSM Pluginの更新に失敗しました"
        return 1
    }
    elseif ($pluginUpdated) {
        Write-LogWarning "SSM Pluginの更新は成功しましたが、AWS CLI v2の更新に失敗しました"
        return 1
    }
    else {
        Write-LogError "AWS CLI v2とSSM Pluginの更新に失敗しました"
        return 1
    }
}

# インスタンスIDを取得する関数
function Get-InstanceId {
    param([string]$Username)
    
    $stackName = "ai-workshop-$Username"
    
    try {
        # CloudFormationスタックからインスタンスIDを取得
        $instanceId = aws cloudformation describe-stacks `
            --stack-name $stackName `
            --profile cline `
            --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' `
            --output text 2>&1
        
        if ($instanceId) {
            return $instanceId
        }
        else {
            return $null
        }
    }
    catch {
        return $null
    }
}

# ポートフォワーディングを開始する関数
function Start-PortForward {
    param(
        [string]$Username,
        [string]$RemotePort = "8080",
        [string]$LocalPort = "18080"
    )
    
    Write-LogInfo "ポートフォワーディングを開始します..."
    
    # インスタンスIDの取得
    $instanceId = Get-InstanceId -Username $Username
    if (-not $instanceId) {
        Write-LogError "インスタンスIDの取得に失敗しました"
        return 1
    }
    
    Write-LogInfo "インスタンスID: $instanceId"
    Write-LogInfo "リモートポート: $RemotePort → ローカルポート: $LocalPort"
    
    # JSONパラメータの作成
    $params = @{
        "portNumber" = @($RemotePort)
        "localPortNumber" = @($LocalPort)
    } | ConvertTo-Json -Compress
    
    # ポートフォワーディングの実行
    try {
        Write-LogInfo "ポートフォワーディングを実行しています..."
        Write-LogInfo "コマンド: aws ssm start-session --target $instanceId --document-name AWS-StartPortForwardingSession --parameters $params --profile cline"
        
        aws ssm start-session `
            --target $instanceId `
            --document-name AWS-StartPortForwardingSession `
            --parameters $params `
            --profile cline
    }
    catch {
        Write-LogError "ポートフォワーディングの実行に失敗しました: $_"
        return 1
    }
}

# AWS認証情報が設定されているか確認する関数
function Test-AwsCredentials {
    Write-LogInfo "AWS 認証情報を確認しています..."
    
    # AWS CLIがインストールされているか確認
    try {
        $null = Get-Command aws -ErrorAction Stop
    }
    catch {
        Write-LogError "AWS CLI がインストールされていません"
        return 1
    }
    
    $defaultProfileOk = $false
    $clineProfileOk = $false
    
    # デフォルトプロファイルの認証情報を確認
    Write-LogInfo "デフォルトプロファイルの認証情報を確認しています..."
    try {
        $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
        Write-LogSuccess "デフォルトプロファイルの認証情報が設定されています"
        Write-LogInfo "アカウント ID: $($identity.Account)"
        Write-LogInfo "ユーザー ARN: $($identity.Arn)"
        $defaultProfileOk = $true
    }
    catch {
        Write-LogWarning "デフォルトプロファイルの認証情報が設定されていないか、無効です"
    }
    
    # clineプロファイルの認証情報を確認
    Write-LogInfo "cline プロファイルの認証情報を確認しています..."
    try {
        $identity = aws sts get-caller-identity --profile cline --output json | ConvertFrom-Json
        Write-LogSuccess "cline プロファイルの認証情報が設定されています"
        Write-LogInfo "アカウント ID: $($identity.Account)"
        Write-LogInfo "ユーザー ARN: $($identity.Arn)"
        $clineProfileOk = $true
    }
    catch {
        Write-LogWarning "cline プロファイルの認証情報が設定されていないか、無効です"
    }
    
    # 結果の返却
    if ($clineProfileOk) {
        # clineプロファイルが設定されていれば成功とする
        return 0
    }
    elseif ($defaultProfileOk) {
        # デフォルトプロファイルのみ設定されている場合は警告を表示
        Write-LogWarning "デフォルトプロファイルは設定されていますが、cline プロファイルが設定されていません"
        Write-LogWarning "ポートフォワーディングには cline プロファイルが必要です"
        return 2
    }
    else {
        # どちらも設定されていない場合はエラー
        Write-LogError "AWS 認証情報が設定されていません"
        return 1
    }
}

# SSM start-sessionコマンドが実行可能か確認する関数
function Test-SsmSession {
    Write-LogInfo "SSM start-session コマンドの実行可能性を確認しています..."
    
    # AWS CLIとSSM Pluginがインストールされているか確認
    try {
        $null = Get-Command aws -ErrorAction Stop
    }
    catch {
        Write-LogWarning "AWS CLIがインストールされていません"
        return 1
    }
    
    try {
        $null = Get-Command session-manager-plugin -ErrorAction Stop
    }
    catch {
        Write-LogWarning "SSM Pluginがインストールされていません"
        return 1
    }
    
    # AWS認証情報が設定されているか確認
    try {
        $null = aws sts get-caller-identity --profile cline
        Write-LogSuccess "SSM start-session コマンドは実行可能です"
        return 0
    }
    catch {
        Write-LogWarning "AWS認証情報が設定されていないか、無効です"
        return 1
    }
}

# チェック結果を表形式で表示する関数
function Show-CheckSummary {
    param(
        [int]$AwsCliStatus,
        [int]$SsmPluginStatus,
        [int]$AwsAuthStatus,
        [int]$SsmSessionStatus
    )
    
    # ステータスを記号に変換
    $awsCliText = "❌ 未インストール"
    $ssmPluginText = "❌ 未インストール"
    $awsAuthText = "❌ 未設定"
    $ssmSessionText = "❌ 実行不可"
    
    if ($AwsCliStatus -eq 0) {
        $awsCliText = "✅ インストール済み"
    }
    elseif ($AwsCliStatus -eq 2) {
        $awsCliText = "⚠️ v1 インストール済み"
    }
    
    if ($SsmPluginStatus -eq 0) {
        $ssmPluginText = "✅ インストール済み"
    }
    
    if ($AwsAuthStatus -eq 0) {
        $awsAuthText = "✅ cline プロファイル設定済み"
    }
    elseif ($AwsAuthStatus -eq 2) {
        $awsAuthText = "⚠️ デフォルトのみ設定済み"
    }
    
    if ($SsmSessionStatus -eq 0) {
        $ssmSessionText = "✅ 実行可能"
    }
    
    # 表の区切り線
    $line = "+-----------------------+------------------+"
    
    # 表の表示
    Write-Host ""
    Write-Host "システム状態の概要:"
    Write-Host $line
    Write-Host "| 項目                  | 状態             |"
    Write-Host $line
    Write-Host "| AWS CLI               | $awsCliText |"
    Write-Host "| SSM Plugin            | $ssmPluginText |"
    Write-Host "| AWS 認証情報          | $awsAuthText |"
    Write-Host "| SSM Session 実行      | $ssmSessionText |"
    Write-Host $line
    Write-Host ""
    
    # 総合判定
    if (($AwsCliStatus -eq 0) -and ($SsmPluginStatus -eq 0) -and ($AwsAuthStatus -eq 0) -and ($SsmSessionStatus -eq 0)) {
        Write-LogSuccess "すべての項目が正常です。システムは完全に設定されています。"
    }
    else {
        Write-LogWarning "一部の項目に問題があります。上記の表を確認して必要な対応を行ってください。"
    }
}

# 総合チェックを行う関数
function Test-All {
    Write-LogInfo "システム全体の状態を確認しています..."
    
    # 各コンポーネントのチェック
    $awsCliStatus = Test-AwsCli
    $ssmPluginStatus = Test-SsmPlugin
    $awsAuthStatus = Test-AwsCredentials
    $ssmSessionStatus = Test-SsmSession
    
    # 結果の表示
    Show-CheckSummary -AwsCliStatus $awsCliStatus -SsmPluginStatus $ssmPluginStatus `
                     -AwsAuthStatus $awsAuthStatus -SsmSessionStatus $ssmSessionStatus
    
    # 総合結果の返却
    if (($awsCliStatus -eq 0) -and ($ssmPluginStatus -eq 0) -and ($awsAuthStatus -eq 0) -and ($ssmSessionStatus -eq 0)) {
        return 0
    }
    else {
        return 1
    }
}

# 使用方法を表示する関数
function Show-Usage {
    Write-Host "使用方法: $($MyInvocation.MyCommand.Name) [オプション]"
    Write-Host "オプション:"
    Write-Host "  --check-only       インストール状況の確認のみを行います"
    Write-Host "  --install          AWS CLI v2とSSM Pluginの両方をインストールします"
    Write-Host "  --install-cli      AWS CLI v2のみをインストールします"
    Write-Host "  --install-plugin   SSM Pluginのみをインストールします"
    Write-Host "  --update           AWS CLI v2とSSM Pluginの両方を更新します"
    Write-Host "  --update-cli       AWS CLI v2のみを更新します"
    Write-Host "  --update-plugin    SSM Pluginのみを更新します"
    Write-Host "  --uninstall-cli    AWS CLI v2をアンインストールします"
    Write-Host "  --uninstall-plugin SSM Pluginをアンインストールします"
    Write-Host "  --port-forward     ポートフォワーディングを開始します"
    Write-Host "    --username       ユーザー名を指定します（必須）"
    Write-Host "    --remote-port    リモートポート番号（デフォルト: 8080）"
    Write-Host "    --local-port     ローカルポート番号（デフォルト: 18080）"
    Write-Host "  --help             このヘルプメッセージを表示します"
    Write-Host ""
    Write-Host "引数なしで実行した場合、ヘルプメッセージを表示します"
}

# メイン処理
function Main {
    param(
        [switch]$CheckOnly,
        [switch]$Install,
        [switch]$InstallCli,
        [switch]$DirectInstall,
        [switch]$InstallPlugin,
        [switch]$UseZip,
        [switch]$Update,
        [switch]$UpdateCli,
        [switch]$UpdatePlugin,
        [switch]$UninstallCli,
        [switch]$UninstallPlugin,
        [switch]$PortForward,
        [string]$Username,
        [string]$RemotePort = "8080",
        [string]$LocalPort = "18080",
        [switch]$Help
    )
    
    # 管理者権限の確認
    if (-not (Test-AdminPrivileges)) {
        Write-LogError "このスクリプトは管理者権限で実行する必要があります"
        return 1
    }
    
    # 引数がない場合はヘルプを表示
    if ($PSBoundParameters.Count -eq 0) {
        Show-Usage
        return 0
    }
    
    # ヘルプの表示
    if ($Help) {
        Show-Usage
        return 0
    }
    
    # 各オプションの処理
    if ($CheckOnly) {
        Test-All
    }
    elseif ($Install) {
        Install-AllTools
    }
    elseif ($InstallCli) {
        Install-AwsCli -DirectInstall:$DirectInstall
    }
    elseif ($InstallPlugin) {
        Install-SsmPlugin -UseZip:$UseZip
    }
    elseif ($Update) {
        Update-AllTools -UseZipForPlugin:$UseZip
    }
    elseif ($UpdateCli) {
        Update-AwsCli
    }
    elseif ($UpdatePlugin) {
        Update-SsmPlugin
    }
    elseif ($UninstallCli) {
        Uninstall-AwsCli
    }
    elseif ($UninstallPlugin) {
        Uninstall-SsmPlugin
    }
    elseif ($PortForward) {
        if (-not $Username) {
            Write-LogError "--username オプションが必要です"
            Show-Usage
            return 1
        }
        Start-PortForward -Username $Username -RemotePort $RemotePort -LocalPort $LocalPort
    }
    else {
        Write-LogError "不明なオプションが指定されました"
        Show-Usage
        return 1
    }
}

# スクリプトの実行
try {
    $params = @{}
    
    # コマンドライン引数の解析
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch ($args[$i]) {
            "--check-only" { $params["CheckOnly"] = $true }
            "--install" { $params["Install"] = $true }
            "--install-cli" { $params["InstallCli"] = $true }
            "--direct-install" { $params["DirectInstall"] = $true }
            "--install-plugin" { $params["InstallPlugin"] = $true }
            "--use-zip" { $params["UseZip"] = $true }
            "--update" { $params["Update"] = $true }
            "--update-cli" { $params["UpdateCli"] = $true }
            "--update-plugin" { $params["UpdatePlugin"] = $true }
            "--uninstall-cli" { $params["UninstallCli"] = $true }
            "--uninstall-plugin" { $params["UninstallPlugin"] = $true }
            "--port-forward" { $params["PortForward"] = $true }
            "--username" { 
                $i++
                if ($i -lt $args.Count) {
                    $params["Username"] = $args[$i]
                }
            }
            "--remote-port" {
                $i++
                if ($i -lt $args.Count) {
                    $params["RemotePort"] = $args[$i]
                }
            }
            "--local-port" {
                $i++
                if ($i -lt $args.Count) {
                    $params["LocalPort"] = $args[$i]
                }
            }
            "--help" { $params["Help"] = $true }
            default {
                Write-LogError "不明な引数: $($args[$i])"
                Show-Usage
                exit 1
            }
        }
    }
    
    # メイン処理の実行
    Main @params
}
catch {
    Write-LogError "予期しないエラーが発生しました: $_"
    exit 1
}
