Configuration Main
{

Param ( [string] $nodeName,
        [string] $firstHtml)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xPSDesiredStateConfiguration
Import-DscResource -Module xWebAdministration
Import-DscResource -Module xNetworking

Node $nodeName
  {
    WindowsFeature WebServer {
      Ensure = "Present"
      Name   = "Web-Server"
    }
    
    WindowsFeature Management {
 
      Name = 'Web-Mgmt-Service'
      Ensure = 'Present'
      DependsOn='[WindowsFeature]WebServer'
    }

    WindowsFeature WebServerManagementConsole
      {
       Name = "Web-Mgmt-Console"
       Ensure = "Present"
       DependsOn='[WindowsFeature]WebServer'
    }

    #  WindowsFeature ASPNet45
    # {
    #   Name = "Web-Asp-Net45"
    #   Ensure = "Present"
    # }

    # Stop the default website 
   xWebsite DefaultSite  
   { 
       Ensure          = "Present" 
        Name            = "Default Web Site" 
        State           = "Stopped" 
        PhysicalPath    = "C:\inetpub\wwwroot" 
        DependsOn       = @('[WindowsFeature]WebServer', '[WindowsFeature]Management')
    } 

    File CreateFirstHtmlDirectory{
      Type = "Directory"
      DestinationPath = "C:\inetpub\wwwroot\first"
      Ensure = "Present"
    }
    xRemoteFile 'PullFirstHtmlFile'{
      Uri = "$firstHtml"
      DestinationPath = "C:\inetpub\wwwroot\first\firstHtml.html"
      MatchSource = $true
      DependsOn = '[File]CreateFirstHtmlDirectory'
    }

    xFirewall ListenPort80
     {
        Name        = 'Open/ListenPort80'
         DisplayName = 'Opened/Listening to port 80'
         Action      = 'Allow'
         Direction   = 'Inbound'
         LocalPort   = '80'
         Protocol    = 'TCP'
         Profile     = 'Any' #?
         Enabled     = 'True'
    }

    xFirewall ListenPort443
     {
        Name        = 'Open/ListenPort443'
        DisplayName = 'Opened/Listening to port 443'
        Action      = 'Allow'
        Direction   = 'Inbound'
        LocalPort   = '443'
        Protocol    = 'TCP'
        Profile     = 'Any' #?
        Enabled     = 'True'
     }

     Script DownloadWebDeploy
    {
        TestScript = {
            Test-Path "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        }
        SetScript ={
            $source = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
            $dest = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
            Invoke-WebRequest $source -OutFile $dest
        }
        GetScript = {@{Result = "DownloadWebDeploy"}}
        DependsOn = "[WindowsFeature]WebServer"
    }
    Package InstallWebDeploy
    {
        Ensure = "Present"  
        Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        Name = "Microsoft Web Deploy 3.6"
        ProductId = "{6773A61D-755B-4F74-95CC-97920E45E696}"
        Arguments = "ADDLOCAL=ALL"
        DependsOn = "[Script]DownloadWebDeploy"
    }
    Service StartWebDeploy
    {                    
        Name = "WMSVC"
        StartupType = "Automatic"
        State = "Running"
        DependsOn = "[Package]InstallWebDeploy"
    }

        # IIS URL Rewrite module download and install
        Package UrlRewrite
        {
            DependsOn = "[WindowsFeature]WebServer"
            Ensure = "Present"
            Name = "IIS URL Rewrite Module 2"
            Path = "http://download.microsoft.com/download/D/D/E/DDE57C26-C62C-4C59-A1BB-31D58B36ADA2/rewrite_amd64_en-US.msi"
            Arguments = '/L*V "C:\WindowsAzure\urlrewriter.txt" /quiet'
            ProductId = "38D32370-3A31-40E9-91D0-D236F47E3C4A"
        }


    xWebsite CreateFirstSite{
      Ensure = "Present"  
      Name = "Karlis1"
      State = "Started"
      DefaultPage = "firstHtml.html"
        PhysicalPath = "C:\inetpub\wwwroot\first\"
        BindingInfo  = @(MSFT_xWebBindingInformation 
        {
            Protocol = 'HTTP'
            Port     = 80
            IPAddress = '*'
        }
        )
        DependsOn = @('[xRemoteFile]PullFirstHtmlFile', '[WindowsFeature]WebServer')
      }
  }
}