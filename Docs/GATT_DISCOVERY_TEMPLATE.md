# H1S GATT Services Discovery Template

**Instructions:** Use nRF Connect to scan and connect to "Baseus Bowie H1S", then fill in this template with what you discover.

---

## Connection Info
- **Device Name (as shown in nRF Connect):** 
- **Device MAC Address:** 
- **Connection Status:** Connected / Not Found
- **Phone/Tablet Model:** 
- **nRF Connect Version:** 

---

## Discovered Services & Characteristics

### Service 1
- **Service UUID:** 
- **Service Name/Type:** 
- **Is Custom (128-bit)?** Yes / No
- **Properties:** (standard/custom/vendor)

#### Characteristic 1.1
- **UUID:** 
- **Properties:** (☐ Read, ☐ Write, ☐ Write Without Response, ☐ Notify, ☐ Indicate)
- **Descriptor:** 
- **Notes:** 

#### Characteristic 1.2
- **UUID:** 
- **Properties:** (☐ Read, ☐ Write, ☐ Write Without Response, ☐ Notify, ☐ Indicate)
- **Descriptor:** 
- **Notes:** 

---

### Service 2
- **Service UUID:** 
- **Service Name/Type:** 
- **Is Custom (128-bit)?** Yes / No

#### Characteristic 2.1
- **UUID:** 
- **Properties:** (☐ Read, ☐ Write, ☐ Write Without Response, ☐ Notify, ☐ Indicate)
- **Descriptor:** 
- **Notes:** 

---

### Service 3+
(Continue for each service discovered)

---

## Key Findings

**Custom Vendor Services Found?** Yes / No

**Likely Command Channels (Write Without Response):**
- UUID: _________________ (Property: Write Without Response)
- UUID: _________________ (Property: Write Without Response)

**Likely Status/Event Channels (Notify):**
- UUID: _________________ (Property: Notify)
- UUID: _________________ (Property: Notify)

**Notable Standard Services (if any):**
- 180A (Device Information): present / absent
- 180D (Heart Rate): present / absent
- 1801 (Generic Attribute): present / absent

---

## Screenshots / Additional Notes

(Paste or link any screenshots from nRF Connect here)

---

## Next Steps for Copilot

Once you fill this in, I will:
1. Cross-reference with PacketLogger findings
2. Map discovered UUIDs to actual commands (ANC, EQ, etc.)
3. Build the control commands for the bash script
