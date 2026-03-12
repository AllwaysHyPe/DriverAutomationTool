![MSEndpointMgr Driver Automation Tool](https://msendpointmgr.com/wp-content/uploads/DAT/DAT8.png)

# Driver Automation Tool 8.0.0

Welcome to the **MSEndpointMgr Driver Automation Tool** — version 8.0.0.

**If you would like to donate to the development of this tool, please use the sponsor button at the top of the page.**

**Scripts, MSIs and downloads contained within are provided with no warranty or liabilities. They are provided as is.**

---

## Current Functionality

✅ OEM Support: Acer, Dell, HP, Lenovo  
✅ Package Type Support: Drivers  
✅ Supported Operating Systems: Windows 11 (22H2, 23H2, 24H2, 25H2)  
✅ Supported Architectures: x64, x86  

## In Progress

🚧 Intune Support  
🚧 Deployment Rings  
🚧 New UI for driver additions to existing packages  
🚧 Custom driver package UI  
🚧 Signed EXE and MSI  

---

## Installation

The latest release is located in [`Current Branch/8.0.0/`](Current%20Branch/8.0.0/).

### MSI Installation (recommended)

Download and run `DriverAutomationTool.msi` from the [`Current Branch/8.0.0/`](Current%20Branch/8.0.0/) folder.

### Manual Installation

1. Copy the `DriverAutomationToolCore` module folder to `C:\Program Files\WindowsPowerShell\Modules`
2. Create a folder and copy `DriverAutomationTool.exe` to it (e.g. `C:\Program Files\MSEndpointMgr\Driver Automation Tool`)
3. Create a `Tools` subfolder and place the latest [CURL](https://curl.se/windows/) binary there
4. Run `DriverAutomationTool.exe`

---

## Implementation Guides

- [Modern Driver Management](https://www.msendpointmgr.com/modern-driver-management/)
- [Modern BIOS Management](https://www.msendpointmgr.com/modern-bios-management/)

---

## FAQ

**Q:** Can you please add model X to the list?  
**A:** The manufacturer provides the model listings for Dell, Lenovo and HP. For Microsoft, models are added manually — so for Surface devices, requests are welcome.
