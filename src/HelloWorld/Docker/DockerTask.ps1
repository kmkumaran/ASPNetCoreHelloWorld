Param(
    [Parameter(ParameterSetName = "Build", Position = 0, Mandatory = $True)]
    [switch]$Build,
    [Parameter(ParameterSetName = "Clean", Position = 0, Mandatory = $True)]
    [switch]$Clean,
    [Parameter(ParameterSetName = "Run", Position = 0, Mandatory = $True)]
    [switch]$Run,
    [parameter(ParameterSetName = "Clean", Position = 1, Mandatory = $True)]
    [parameter(ParameterSetName = "Build", Position = 1, Mandatory = $True)]
    [parameter(ParameterSetName = "Run", Position = 1, Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$Environment,
    [parameter(ParameterSetName = "Clean", Position = 2, Mandatory = $False)]
    [parameter(ParameterSetName = "Build", Position = 2, Mandatory = $False)]
    [parameter(ParameterSetName = "Run", Position = 2, Mandatory = $False)]
    [String]$Machine,
    [parameter(ParameterSetName = "Clean", Position = 3, Mandatory = $False)]
    [parameter(ParameterSetName = "Build", Position = 3, Mandatory = $False)]
    [parameter(ParameterSetName = "Run", Position = 3, Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]$ProjectFolder = "$(Get-Location)",
    [parameter(ParameterSetName = "Build", Position = 4, Mandatory = $False)]
    [switch]$NoCache,
    [parameter(ParameterSetName = "Build", Position = 5, Mandatory = $False)]
    [parameter(ParameterSetName = "Run", Position = 4, Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]$ContainerPort = 5000,
    [parameter(ParameterSetName = "Build", Position = 6, Mandatory = $False)]
    [parameter(ParameterSetName = "Run", Position = 5, Mandatory = $False)]
    [ValidateNotNullOrEmpty()]
    [String]$HostPort = 80
)

$ErrorActionPreference = "Stop"

# Kills all containers using an image, removes all containers using an image, and removes the image.
function Clean() {
    $composeFileName = Join-Path $ProjectFolder (Join-Path Docker "docker-compose.$Environment.yml")

    if (Test-Path $composeFileName) {
        Write-Host "Cleaning image $ImageName"

        cmd /c docker-compose -f $composeFileName -p $ProjectName kill "2>&1"
        if($? -eq $False) {
            Write-Error "Failed to kill the running containers"
        }

        cmd /c docker-compose -f $composeFileName -p $ProjectName rm -f "2>&1"
        if($? -eq $False) {
            Write-Error "Failed to remove the stopped containers"
        }

        $ImageNameRegEx = "\b$ImageName\b"

        # If $ImageName exists remove it
        docker images | select-string -pattern $ImageNameRegEx | foreach {
            $imageName = $_.Line.split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)[0];
            $tag = $_.Line.split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)[1];
            Write-Host "Removing image ${imageName}:$tag";
            docker rmi ${imageName}:$tag *>&1 | Out-Null
        }
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}

# Runs docker build.
function Build () {
    $composeFileName = Join-Path $ProjectFolder (Join-Path Docker "docker-compose.$Environment.yml")

    if (Test-Path $composeFileName) {
        $buildArgs = ""
        if($NoCache)
        {
            $buildArgs = "--no-cache"
        }

        cmd /c docker-compose -f $composeFileName -p $ProjectName build $buildArgs "2>&1"
        if($? -eq $False) {
            Write-Error "Failed to build the image"
        }

        $tag = [System.DateTime]::Now.ToString("yyyy-MM-dd_HH-mm-ss")

        cmd /c docker tag $ImageName ${ImageName}:$tag "2>&1"
        if($? -eq $False) {
            Write-Error "Failed to tag the image"
        }
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}

# Runs docker run
function Run () {
    $composeFileName = Join-Path $ProjectFolder (Join-Path Docker "docker-compose.$Environment.yml")

    if (Test-Path $composeFileName) {
        $conflictingContainerIds = $(docker ps -a | select-string -pattern ":$HostPort->" | foreach { Write-Output $_.Line.split()[0] })

        if ($conflictingContainerIds) {
            $conflictingContainerIds = $conflictingContainerIds -Join ' '
            Write-Host "Stoping conflicting containers using port ${Port}"
            cmd /c docker stop $conflictingContainerIds "2>&1"
        }

        cmd /c docker-compose -f $composeFileName -p $ProjectName up -d "2>&1"
        if($? -eq $False) {
            Write-Error "Failed to build the images"
        }
    }
    else {
        Write-Error -Message "$Environment is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }

    OpenSite
}

# Opens the remote site
function OpenSite () {
    if ([System.String]::IsNullOrWhiteSpace($Machine)) {
        $uri = "http://docker:$HostPort"
    }
    else {
        $uri = "http://$(docker-machine ip ${Machine}):$HostPort"
    }
    Write-Host "Opening site $uri " -NoNewline
    $status = 0

    #Check if the site is available
    while($status -ne 200) {
        try {
            $response = Invoke-WebRequest -Uri $uri -Headers @{"Cache-Control"="no-cache";"Pragma"="no-cache"} -UseBasicParsing
            $status = [int]$response.StatusCode
        }
        catch [System.Net.WebException] { }
        if($status -ne 200) {
            Write-Host "." -NoNewline
            Start-Sleep 1
        }
    }

    Write-Host
    # Open the site.
    Start-Process $uri
}

if (![System.String]::IsNullOrWhiteSpace($Machine)) {
# Set the environment variables for the docker machine to connect to
    docker-machine env $Machine --shell powershell | Invoke-Expression
}

# Need the full path of the project for mapping
$ProjectFolder = Resolve-Path $ProjectFolder

$users = Split-Path $env:USERPROFILE -Parent
if (!$ProjectFolder.StartsWith($users, [StringComparison]::InvariantCultureIgnoreCase)) {
   $message  = "VirutalBox by default shares C:\Users as c/Users. If the project is not under c:\Users, please manually add it to the shared folders on VirtualBox. "`
             + "Follow instructions from https://www.virtualbox.org/manual/ch04.html#sharedfolders"
   Write-Warning -Message $message
}
else {
   if (!$ProjectFolder.StartsWith($users, [StringComparison]::InvariantCulture)) {
      # If the project is under C:\Users, fix the casing if necessary. Path in Linux is case sensitive and the default shared folder c/Users
      # on VirtualBox can only be accessed if the project folder starts with the correct casing C:\Users as in $env:USERPROFILE
      $ProjectFolder = $users + $ProjectFolder.Substring($users.Length)
   }
}

# Get the name of the project folder to use for docker-compose's project name
$ProjectName = (Split-Path $ProjectFolder -Leaf).ToLowerInvariant()

# Calculate the name of the image created by the compose file
$ImageName = "${ProjectName}_helloworld"

$env:HELLOWORLD_PORT = $ContainerPort
$env:HOST_PORT = $HostPort

# Call the correct functions for the parameters that were used
if ($Clean) {
    Clean
}
if($Build) {
    Build
}
if($Run) {
    Run
}