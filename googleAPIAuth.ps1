# A PowerShell script for retrieving a refresh token from Google

# Before running this script, you need to set these three values.  They can be
# obtained from the GCP console.
$clientId = "YOUR_CLIENT_ID"
$clientSecret = "YOUR_CLIENT_SECRET"
$redirectUrl = "http://127.0.0.1/"

# This is the access scope we will be requesting
$scope = "https://www.googleapis.com/auth/bigquery"


# Declare a function that will show the OAUTH window to prompt for credentials
Add-Type -AssemblyName System.Web
Function Show-OAuthWindow
{
    param(
        [System.Uri]$Url
    )


    Add-Type -AssemblyName System.Windows.Forms
 
    $form = New-Object -TypeName System.Windows.Forms.Form -Property @{Width=440;Height=640}
    $web  = New-Object -TypeName System.Windows.Forms.WebBrowser -Property @{Width=420;Height=600;Url=($url ) }
    $DocComp  = {
        $Global:uri = $web.Url.AbsoluteUri
        if ($Global:Uri -match "error=[^&]*|code=[^&]*") {$form.Close() }
    }
    $web.ScriptErrorsSuppressed = $true
    $web.Add_DocumentCompleted($DocComp)
    $form.Controls.Add($web)
    $form.Add_Shown({$form.Activate()})
    $form.ShowDialog() | Out-Null

    $queryOutput = [System.Web.HttpUtility]::ParseQueryString($web.Url.Query)
    $output = @{}
    foreach($key in $queryOutput.Keys){
        $output["$key"] = $queryOutput[$key]
    }
    
    $output
}


# Build the URL for Google's OAuth service
$authUrl = "https://accounts.google.com/o/oauth2/v2/auth"
$authUrl += "?client_id=" + $clientId
$authUrl += "&redirect_uri=" + [uri]::EscapeDataString($redirectUrl)
$authUrl += "&scope=" + [uri]::EscapeDataString($scope)
$authUrl += "&access_type=offline&include_granted_scopes=true&response_type=code&prompt=consent"


# Open the window so the user can authenticate to Google's service
$queryOutput = Show-OAuthWindow -Url $authUrl
$accessCode = $queryOutput.code


# Construct URL and parameters for HTTP POST that will be used to exchange the
# access code for an access token and a refresh token
$authUrl = "https://www.googleapis.com/oauth2/v4/token"
$postParams = @{code=$accessCode;
                client_id=$clientId;
                client_secret=$clientSecret;
                redirect_uri=$redirectUrl;
                grant_type="authorization_code"}


# make the HTTP request
try {
   $refreshOutput = Invoke-WebRequest -Uri $authUrl -Method POST -Body $postParams
}
catch {
   echo '### ERROR TRYING TO REDEEM ACCESS CODE ###'
   $ErrorMessage = $_.Exception.Message
   $FailedItem = $_.Exception.ItemName
   $result = $_.Exception.Response.GetResponseStream()
   $reader = New-Object System.IO.StreamReader($result)
   $responseBody = $reader.ReadToEnd();
   echo '## responseBody ##' $responseBody
   throw
}


# If we were successful, extract the refresh token from the HTTP response
$refreshOutputContent = ConvertFrom-Json $refreshOutput.Content
$refreshToken = $refreshOutputContent.refresh_token


# Display our findings!
$output = @{"Client Id" = $clientId;
            "Client Secret" = $clientSecret;
            "Refresh Token" = $refreshToken}
echo ""
echo "--------------------------------------------------------------------------------"
echo "In Azure Data Factory, create a linked service to Google BigQuery."
echo "Set the ""Authentication type"" to ""User Authentication""."
echo "Use the following values for the remaining fields:"
$output