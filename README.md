///////////DESIGN AND IMPLEMENTAION IMPORTAINT INFO AND ASSUMPTIONS///////
- This is an implementation for the PCIe 5.0 MAC Layer.
- The design is parameterized to support two different architectures for interfacing with the lower part (electrical part) of the physical layer:
  1. SERDES architecture
  2. Standard PIPE architecture
- The interfacing with the DLL is of fixed size (32-byte data and other control bits used as indicators).
- The LTSSM is designed to support only detect, polling, configuration, L0, and recovery states. Other states like loopback and power states are left for future work.
- The design is based on the "PCI Express® Base Specification Revision 5.0 Version 1.0 reference."
- The interfacing with the PIPE is based on "PHY Interface for the PCI Express* Architecture."
- Any receiver detection operation is assumed to be handled by the electrical part.
- Any block for Gen1 works only during initial link training. After the link has successfully transitioned to L0, it goes to recovery for higher speeds.
  This means data received from DLL is only considered after speeding up the link; before that, only idles are sent.
  This simplifies the design of the block responsible for packet framing so that it only follows the framing rules for higher generations.
- max number of lanes are assumed to be 32.
- the design can work with one lane or all lanes (32) but in-between number of lanes are not supported

  //////////////////////////////////////SYNTHESIS INFO///////////////////////////////////////////
  - the technology used is 130n
  - the running clock is assumed to be 125Mhz, since due to limitations imposed by this technology 4GHz (32GT "gen5 rate "/8 "symbol bits"") is not affordable
  - if the 32 lanes are in operation then the 32GT/S is virtually achieved (125M*32*8)
  - the design still works with zero slack whe the period is lowered to 7ns
 
/////***************************************** for more info abot the design details, check the documentation folder*******************************/////
