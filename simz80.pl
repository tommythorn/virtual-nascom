print <<"EOT";
/* Z80 instruction set simulator.
   Copyright (C) 1995  Frank D. Cringle.

This file is part of yaze - yet another Z80 emulator.

Yaze is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. */

EOT


# This perl script generates the z80 instruction set simulator simz80().

# Because simz80() is the function which determines the speed of the
# emulator, it can be interesting to experiment with different coding
# styles.  Using perl to generate the final C code helps to separate
# the logic of the emulator from implementation details, such as whether
# to use sub-functions or inline code for handling extended opcodes.

# Set $combine = 1 to insert goto's where possible to combine
# identical instruction sequences at the end of switch branches.
# If $combine is not set (or set = 0), the generated code will be
# larger but there will be fewer jump instructions during execution.
# Thus the code may execute faster on a machine with slow branches and
# no cache or one with a large instruction cache. The compiler and
# optimizer will also play a role, so the best choice for a particular
# environment must by found empirically.

$combine = 0;

# Set $optab = 1 to use an array of labels instead of a switch for the
# main op-code dispatch function.  This only works with gcc, and
# actually produces worse code with gcc-2.6.1 on a sparc.

$optab = 0;

# Set $xx_inline = 1 to generate inline code for the instruction prefix xx.
# If $xx_inline is undefined or 0, prefix xx will be handled by a separate
# function which does not have access to the local variables of the main
# simz80() function.

$cb_inline = 0;
$dfd_inline = 0;
$ed_inline = 1;
# ****************

##### end of configuration options ####

$f = __FILE__;
print <<"EOT";
/* This file was generated from $f
   with the following choice of options */
char *perl_params =
    "combine=$combine,"
    "optab=$optab,"
    "cb_inline=$cb_inline,"
    "dfd_inline=$dfd_inline,"
    "ed_inline=$ed_inline";

EOT

$tab = "\t";
$cblabno = 0;

&preamble;			# generate the function header and switch

&case(0x00, "NOP");
&case(0x01, "LD BC,nnnn");	&LDddnn(BC);
&case(0x02, "LD (BC),A");	print "\t\tPutBYTE(BC, hreg(AF));\n";
&case(0x03, "INC BC");		print "\t\t++BC;\n";
&case(0x04, "INC B");		&INCr(BC, "h");
&case(0x05, "DEC B");		&DECr(BC, "h");
&case(0x06, "LD B,nn");		print "\t\tSethreg(BC, GetBYTE(PC)); ++PC;\n";
&case(0x07, "RLCA");		print <<"EOT";
		AF = ((AF >> 7) & 0x0128) | ((AF << 1) & ~0x1ff) |
			(AF & 0xc4) | ((AF >> 15) & 1);
EOT
&case(0x08, "EX AF,AF'");	print <<"EOT";
		af[af_sel] = AF;
		af_sel = 1 - af_sel;
		AF = af[af_sel];
EOT
&case(0x09, "ADD HL,BC");	&ADDdd(HL, BC);
&case(0x0A, "LD A,(BC)");	print "\t\tSethreg(AF, GetBYTE(BC));\n";
&case(0x0B, "DEC BC");		print "\t\t--BC;\n";
&case(0x0C, "INC C");		&INCr(BC, "l");
&case(0x0D, "DEC C");		&DECr(BC, "l");
&case(0x0E, "LD C,nn");		print "\t\tSetlreg(BC, GetBYTE(PC)); ++PC;\n";
&case(0x0F, "RRCA");		print <<"EOT";
		temp = hreg(AF);
		sum = temp >> 1;
		AF = ((temp & 1) << 15) | (sum << 8) |
			(sum & 0x28) | (AF & 0xc4) | (temp & 1);
EOT
&case(0x10, "DJNZ dd");		&JRcond("(BC -= 0x100) & 0xff00");
&case(0x11, "LD DE,nnnn");	&LDddnn(DE);
&case(0x12, "LD (DE),A");	print "\t\tPutBYTE(DE, hreg(AF));\n";
&case(0x13, "INC DE");		print "\t\t++DE;\n";
&case(0x14, "INC D");           &INCr(DE, "h");
&case(0x15, "DEC D");           &DECr(DE, "h");
&case(0x16, "LD D,nn");		print "\t\tSethreg(DE, GetBYTE(PC)); ++PC;\n";
&case(0x17, "RLA");		print <<"EOT";
		AF = ((AF << 8) & 0x0100) | ((AF >> 7) & 0x28) | ((AF << 1) & ~0x01ff) |
			(AF & 0xc4) | ((AF >> 15) & 1);
EOT
&case(0x18, "JR dd");		&JRcond(1);
&case(0x19, "ADD HL,DE");	&ADDdd(HL, DE);
&case(0x1A, "LD A,(DE)");	print "\t\tSethreg(AF, GetBYTE(DE));\n";
&case(0x1B, "DEC DE");		print "\t\t--DE;\n";
&case(0x1C, "INC E");           &INCr(DE, "l");
&case(0x1D, "DEC E");           &DECr(DE, "l");
&case(0x1E, "LD E,nn");		print "\t\tSetlreg(DE, GetBYTE(PC)); ++PC;\n";
&case(0x1F, "RRA");		print <<"EOT";
		temp = hreg(AF);
		sum = temp >> 1;
		AF = ((AF & 1) << 15) | (sum << 8) |
			(sum & 0x28) | (AF & 0xc4) | (temp & 1);
EOT
&case(0x20, "JR NZ,dd");	&JRcond("!TSTFLAG(Z)");
&case(0x21, "LD HL,nnnn");	&LDddnn(HL);
&case(0x22, "LD (nnnn),HL");	&LDmemdd(HL);
&case(0x23, "INC HL");          print "\t\t++HL;\n";
&case(0x24, "INC H");           &INCr(HL, "h");
&case(0x25, "DEC H");           &DECr(HL, "h");
&case(0x26, "LD H,nn");         print "\t\tSethreg(HL, GetBYTE(PC)); ++PC;\n";
&case(0x27, "DAA");		print <<"EOT";
		acu = hreg(AF);
		temp = ldig(acu);
		cbits = TSTFLAG(C);
		if (TSTFLAG(N)) {	/* last operation was a subtract */
			int hd = cbits || acu > 0x99;
			if (TSTFLAG(H) || (temp > 9)) { /* adjust low digit */
				if (temp > 5)
					SETFLAG(H, 0);
				acu -= 6;
				acu &= 0xff;
			}
			if (hd)		/* adjust high digit */
				acu -= 0x160;
		}
		else {			/* last operation was an add */
			if (TSTFLAG(H) || (temp > 9)) { /* adjust low digit */
				SETFLAG(H, (temp > 9));
				acu += 6;
			}
			if (cbits || ((acu & 0x1f0) > 0x90)) /* adjust high digit */
				acu += 0x60;
		}
		cbits |= (acu >> 8) & 1;
		acu &= 0xff;
		AF = (acu << 8) | (acu & 0xa8) | ((acu == 0) << 6) |
			(AF & 0x12) | partab[acu] | cbits;
EOT
&case(0x28, "JR Z,dd");		&JRcond("TSTFLAG(Z)");
&case(0x29, "ADD HL,HL");	&ADDdd(HL, HL);
&case(0x2A, "LD HL,(nnnn)");	&LDddmem(HL);
&case(0x2B, "DEC HL");          print "\t\t--HL;\n";
&case(0x2C, "INC L");           &INCr(HL, "l");
&case(0x2D, "DEC L");           &DECr(HL, "l");
&case(0x2E, "LD L,nn");		print "\t\tSetlreg(HL, GetBYTE(PC)); ++PC;\n";
&case(0x2F, "CPL");		print <<"EOT";
		AF = (~AF & ~0xff) | (AF & 0xc5) | ((~AF >> 8) & 0x28) | 0x12;
EOT
&case(0x30, "JR NC,dd");	&JRcond("!TSTFLAG(C)");
&case(0x31, "LD SP,nnnn");	&LDddnn(SP);
&case(0x32, "LD (nnnn),A");	&LDmemr(AF, "h");
&case(0x33, "INC SP");		print "\t\t++SP;\n";
&case(0x34, "INC (HL)");	&INCm(HL);
&case(0x35, "DEC (HL)");	&DECm(HL);
&case(0x36, "LD (HL),nn");	print "\t\tPutBYTE(HL, GetBYTE(PC)); ++PC;\n";
&case(0x37, "SCF");		print "\t\tAF = (AF&~0x3b)|((AF>>8)&0x28)|1;\n";
&case(0x38, "JR C,dd");		&JRcond("TSTFLAG(C)");
&case(0x39, "ADD HL,SP");	&ADDdd(HL, SP);
&case(0x3A, "LD A,(nnnn)");	&LDrmem(AF, "h");
&case(0x3B, "DEC SP");		print "\t\t--SP;\n";
&case(0x3C, "INC A");		&INCr(AF, "h");
&case(0x3D, "DEC A");		&DECr(AF, "h");
&case(0x3E, "LD A,nn");		print "\t\tSethreg(AF, GetBYTE(PC)); ++PC;\n";
&case(0x3F, "CCF");
	print "\t\tAF = (AF&~0x3b)|((AF>>8)&0x28)|((AF&1)<<4)|(~AF&1);\n";
&case(0x40, "LD B,B");		print "\t\t/* nop */\n";
&case(0x41, "LD B,C");		print "\t\tBC = (BC & 255) | ((BC & 255) << 8);\n";
&case(0x42, "LD B,D");		print "\t\tBC = (BC & 255) | (DE & ~255);\n";
&case(0x43, "LD B,E");		print "\t\tBC = (BC & 255) | ((DE & 255) << 8);\n";
&case(0x44, "LD B,H");		print "\t\tBC = (BC & 255) | (HL & ~255);\n";
&case(0x45, "LD B,L");		print "\t\tBC = (BC & 255) | ((HL & 255) << 8);\n";
&case(0x46, "LD B,(HL)");	print "\t\tSethreg(BC, GetBYTE(HL));\n";
&case(0x47, "LD B,A");		print "\t\tBC = (BC & 255) | (AF & ~255);\n";
&case(0x48, "LD C,B");		print "\t\tBC = (BC & ~255) | ((BC >> 8) & 255);\n";
&case(0x49, "LD C,C");		print "\t\t/* nop */\n";
&case(0x4A, "LD C,D");          print "\t\tBC = (BC & ~255) | ((DE >> 8) & 255);\n";
&case(0x4B, "LD C,E");          print "\t\tBC = (BC & ~255) | (DE & 255);\n";
&case(0x4C, "LD C,H");          print "\t\tBC = (BC & ~255) | ((HL >> 8) & 255);\n";
&case(0x4D, "LD C,L");          print "\t\tBC = (BC & ~255) | (HL & 255);\n";
&case(0x4E, "LD C,(HL)");	print "\t\tSetlreg(BC, GetBYTE(HL));\n";
&case(0x4F, "LD C,A");		print "\t\tBC = (BC & ~255) | ((AF >> 8) & 255);\n";
&case(0x50, "LD D,B");		print "\t\tDE = (DE & 255) | (BC & ~255);\n";
&case(0x51, "LD D,C");		print "\t\tDE = (DE & 255) | ((BC & 255) << 8);\n";
&case(0x52, "LD D,D");		print "\t\t/* nop */\n";
&case(0x53, "LD D,E");		print "\t\tDE = (DE & 255) | ((DE & 255) << 8);\n";
&case(0x54, "LD D,H");		print "\t\tDE = (DE & 255) | (HL & ~255);\n";
&case(0x55, "LD D,L");		print "\t\tDE = (DE & 255) | ((HL & 255) << 8);\n";
&case(0x56, "LD D,(HL)");	print "\t\tSethreg(DE, GetBYTE(HL));\n";
&case(0x57, "LD D,A");		print "\t\tDE = (DE & 255) | (AF & ~255);\n";
&case(0x58, "LD E,B");		print "\t\tDE = (DE & ~255) | ((BC >> 8) & 255);\n";
&case(0x59, "LD E,C");		print "\t\tDE = (DE & ~255) | (BC & 255);\n";
&case(0x5A, "LD E,D");		print "\t\tDE = (DE & ~255) | ((DE >> 8) & 255);\n";
&case(0x5B, "LD E,E");		print "\t\t/* nop */\n";
&case(0x5C, "LD E,H");		print "\t\tDE = (DE & ~255) | ((HL >> 8) & 255);\n";
&case(0x5D, "LD E,L");		print "\t\tDE = (DE & ~255) | (HL & 255);\n";
&case(0x5E, "LD E,(HL)");	print "\t\tSetlreg(DE, GetBYTE(HL));\n";
&case(0x5F, "LD E,A");		print "\t\tDE = (DE & ~255) | ((AF >> 8) & 255);\n";
&case(0x60, "LD H,B");		print "\t\tHL = (HL & 255) | (BC & ~255);\n";
&case(0x61, "LD H,C");		print "\t\tHL = (HL & 255) | ((BC & 255) << 8);\n";
&case(0x62, "LD H,D");		print "\t\tHL = (HL & 255) | (DE & ~255);\n";
&case(0x63, "LD H,E");		print "\t\tHL = (HL & 255) | ((DE & 255) << 8);\n";
&case(0x64, "LD H,H");		print "\t\t/* nop */\n";
&case(0x65, "LD H,L");		print "\t\tHL = (HL & 255) | ((HL & 255) << 8);\n";
&case(0x66, "LD H,(HL)");	print "\t\tSethreg(HL, GetBYTE(HL));\n";
&case(0x67, "LD H,A");		print "\t\tHL = (HL & 255) | (AF & ~255);\n";
&case(0x68, "LD L,B");		print "\t\tHL = (HL & ~255) | ((BC >> 8) & 255);\n";
&case(0x69, "LD L,C");		print "\t\tHL = (HL & ~255) | (BC & 255);\n";
&case(0x6A, "LD L,D");		print "\t\tHL = (HL & ~255) | ((DE >> 8) & 255);\n";
&case(0x6B, "LD L,E");		print "\t\tHL = (HL & ~255) | (DE & 255);\n";
&case(0x6C, "LD L,H");		print "\t\tHL = (HL & ~255) | ((HL >> 8) & 255);\n";
&case(0x6D, "LD L,L");		print "\t\t/* nop */\n";
&case(0x6E, "LD L,(HL)");	print "\t\tSetlreg(HL, GetBYTE(HL));\n";
&case(0x6F, "LD L,A");		print "\t\tHL = (HL & ~255) | ((AF >> 8) & 255);\n";
&case(0x70, "LD (HL),B");	print "\t\tPutBYTE(HL, hreg(BC));\n";
&case(0x71, "LD (HL),C");	print "\t\tPutBYTE(HL, lreg(BC));\n";
&case(0x72, "LD (HL),D");	print "\t\tPutBYTE(HL, hreg(DE));\n";
&case(0x73, "LD (HL),E");	print "\t\tPutBYTE(HL, lreg(DE));\n";
&case(0x74, "LD (HL),H");	print "\t\tPutBYTE(HL, hreg(HL));\n";
&case(0x75, "LD (HL),L");	print "\t\tPutBYTE(HL, lreg(HL));\n";
&case(0x76, "HALT");		print "\t\tSAVE_STATE();\n\t\treturn PC&0xffff;\n"; $needbreak = 0;
&case(0x77, "LD (HL),A");	print "\t\tPutBYTE(HL, hreg(AF));\n";
&case(0x78, "LD A,B");		print "\t\tAF = (AF & 255) | (BC & ~255);\n";
&case(0x79, "LD A,C");		print "\t\tAF = (AF & 255) | ((BC & 255) << 8);\n";
&case(0x7A, "LD A,D");		print "\t\tAF = (AF & 255) | (DE & ~255);\n";
&case(0x7B, "LD A,E");		print "\t\tAF = (AF & 255) | ((DE & 255) << 8);\n";
&case(0x7C, "LD A,H");		print "\t\tAF = (AF & 255) | (HL & ~255);\n";
&case(0x7D, "LD A,L");		print "\t\tAF = (AF & 255) | ((HL & 255) << 8);\n";
&case(0x7E, "LD A,(HL)");	print "\t\tSethreg(AF, GetBYTE(HL));\n";
&case(0x7F, "LD A,A");		print "\t\t/* nop */\n";
&case(0x80, "ADD A,B");		&ADDAr("hreg(BC)");
&case(0x81, "ADD A,C");		&ADDAr("lreg(BC)");
&case(0x82, "ADD A,D");		&ADDAr("hreg(DE)");
&case(0x83, "ADD A,E");		&ADDAr("lreg(DE)");
&case(0x84, "ADD A,H");		&ADDAr("hreg(HL)");
&case(0x85, "ADD A,L");		&ADDAr("lreg(HL)");
&case(0x86, "ADD A,(HL)");	&ADDAr("GetBYTE(HL)");
&case(0x87, "ADD A,A");		&ADDAr("hreg(AF)");
&case(0x88, "ADC A,B");		&ADCAr("hreg(BC)");
&case(0x89, "ADC A,C");		&ADCAr("lreg(BC)");
&case(0x8A, "ADC A,D");		&ADCAr("hreg(DE)");
&case(0x8B, "ADC A,E");		&ADCAr("lreg(DE)");
&case(0x8C, "ADC A,H");		&ADCAr("hreg(HL)");
&case(0x8D, "ADC A,L");		&ADCAr("lreg(HL)");
&case(0x8E, "ADC A,(HL)");	&ADCAr("GetBYTE(HL)");
&case(0x8F, "ADC A,A");		&ADCAr("hreg(AF)");
&case(0x90, "SUB B");		&SUBAr("hreg(BC)");
&case(0x91, "SUB C");		&SUBAr("lreg(BC)");
&case(0x92, "SUB D");		&SUBAr("hreg(DE)");
&case(0x93, "SUB E");		&SUBAr("lreg(DE)");
&case(0x94, "SUB H");		&SUBAr("hreg(HL)");
&case(0x95, "SUB L");		&SUBAr("lreg(HL)");
&case(0x96, "SUB (HL)");	&SUBAr("GetBYTE(HL)");
&case(0x97, "SUB A");		&SUBAr("hreg(AF)");
&case(0x98, "SBC A,B");		&SBCAr("hreg(BC)");
&case(0x99, "SBC A,C");		&SBCAr("lreg(BC)");
&case(0x9A, "SBC A,D");		&SBCAr("hreg(DE)");
&case(0x9B, "SBC A,E");		&SBCAr("lreg(DE)");
&case(0x9C, "SBC A,H");		&SBCAr("hreg(HL)");
&case(0x9D, "SBC A,L");		&SBCAr("lreg(HL)");
&case(0x9E, "SBC A,(HL)");	&SBCAr("GetBYTE(HL)");
&case(0x9F, "SBC A,A");		&SBCAr("hreg(AF)");
&case(0xA0, "AND B");		&ANDAh("&", "BC");
&case(0xA1, "AND C");		&ANDAl("&", "BC");
&case(0xA2, "AND D");		&ANDAh("&", "DE");
&case(0xA3, "AND E");		&ANDAl("&", "DE");
&case(0xA4, "AND H");		&ANDAh("&", "HL");
&case(0xA5, "AND L");		&ANDAl("&", "HL");
&case(0xA6, "AND (HL)");	&ANDAl("&", "GetBYTE(HL)");
&case(0xA7, "AND A");		&ANDAh("&", "AF");
&case(0xA8, "XOR B");		&LOGAh("^", "BC");
&case(0xA9, "XOR C");		&LOGAl("^", "BC");
&case(0xAA, "XOR D");		&LOGAh("^", "DE");
&case(0xAB, "XOR E");		&LOGAl("^", "DE");
&case(0xAC, "XOR H");		&LOGAh("^", "HL");
&case(0xAD, "XOR L");		&LOGAl("^", "HL");
&case(0xAE, "XOR (HL)");	&LOGAl("^", "GetBYTE(HL)");
&case(0xAF, "XOR A");		&LOGAh("^", "AF");
&case(0xB0, "OR B");		&LOGAh("|", "BC");
&case(0xB1, "OR C");		&LOGAl("|", "BC");
&case(0xB2, "OR D");		&LOGAh("|", "DE");
&case(0xB3, "OR E");		&LOGAl("|", "DE");
&case(0xB4, "OR H");		&LOGAh("|", "HL");
&case(0xB5, "OR L");		&LOGAl("|", "HL");
&case(0xB6, "OR (HL)");		&LOGAl("|", "GetBYTE(HL)");
&case(0xB7, "OR A");		&LOGAh("|", "AF");
&case(0xB8, "CP B");		&CPAr("hreg(BC)");
&case(0xB9, "CP C");		&CPAr("lreg(BC)");
&case(0xBA, "CP D");		&CPAr("hreg(DE)");
&case(0xBB, "CP E");		&CPAr("lreg(DE)");
&case(0xBC, "CP H");		&CPAr("hreg(HL)");
&case(0xBD, "CP L");		&CPAr("lreg(HL)");
&case(0xBE, "CP (HL)");		&CPAr("GetBYTE(HL)");
&case(0xBF, "CP A");		&CPAr("hreg(AF)");
&case(0xC0, "RET NZ");		print "\t\tif (!TSTFLAG(Z)) POP(PC);\n";
&case(0xC1, "POP BC");		print "\t\tPOP(BC);\n";
&case(0xC2, "JP NZ,nnnn");	print "\t\tJPC(!TSTFLAG(Z));\n";
&case(0xC3, "JP nnnn");		print "\t\tJPC(1);\n";
&case(0xC4, "CALL NZ,nnnn");	print "\t\tCALLC(!TSTFLAG(Z));\n";
&case(0xC5, "PUSH BC");		print "\t\tPUSH(BC);\n";
&case(0xC6, "ADD A,nn");	&ADDAr("GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xC7, "RST 0");		print "\t\tPUSH(PC); PC = 0;\n";
&case(0xC8, "RET Z");		print "\t\tif (TSTFLAG(Z)) POP(PC);\n";
&case(0xC9, "RET");		print "\t\tPOP(PC);\n";
&case(0xCA, "JP Z,nnnn");	print "\t\tJPC(TSTFLAG(Z));\n";
&case(0xCB, "CB prefix");	&CB("HL");
&case(0xCC, "CALL Z,nnnn");	print "\t\tCALLC(TSTFLAG(Z));\n";
&case(0xCD, "CALL nnnn");	print "\t\tCALLC(1);\n";
&case(0xCE, "ADC A,nn");	&ADCAr("GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xCF, "RST 8");		print "\t\tPUSH(PC); PC = 8;\n";
&case(0xD0, "RET NC");		print "\t\tif (!TSTFLAG(C)) POP(PC);\n";
&case(0xD1, "POP DE");		print "\t\tPOP(DE);\n";
&case(0xD2, "JP NC,nnnn");	print "\t\tJPC(!TSTFLAG(C));\n";
&case(0xD3, "OUT (nn),A");	print "\t\tOutput(GetBYTE(PC), hreg(AF)); ++PC;\n";
&case(0xD4, "CALL NC,nnnn");	print "\t\tCALLC(!TSTFLAG(C));\n";
&case(0xD5, "PUSH DE");		print "\t\tPUSH(DE);\n";
&case(0xD6, "SUB nn");		&SUBAr("GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xD7, "RST 10H");		print "\t\tPUSH(PC); PC = 0x10;\n";
&case(0xD8, "RET C");		print "\t\tif (TSTFLAG(C)) POP(PC);\n";
&case(0xD9, "EXX");		print <<"EOT";
		regs[regs_sel].bc = BC;
		regs[regs_sel].de = DE;
		regs[regs_sel].hl = HL;
		regs_sel = 1 - regs_sel;
		BC = regs[regs_sel].bc;
		DE = regs[regs_sel].de;
		HL = regs[regs_sel].hl;
EOT
&case(0xDA, "JP C,nnnn");	print "\t\tJPC(TSTFLAG(C));\n";
&case(0xDB, "IN A,(nn)");	print "\t\tSethreg(AF, Input(GetBYTE(PC))); ++PC;\n";
&case(0xDC, "CALL C,nnnn");	print "\t\tCALLC(TSTFLAG(C));\n";
&case(0xDD, "DD prefix");	$dfd_inline ? &DFD("IX") : &DFD("ix");
&case(0xDE, "SBC A,nn");	&SBCAr("GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xDF, "RST 18H");		print "\t\tPUSH(PC); PC = 0x18;\n";
&case(0xE0, "RET PO");		print "\t\tif (!TSTFLAG(P)) POP(PC);\n";
&case(0xE1, "POP HL");		print "\t\tPOP(HL);\n";
&case(0xE2, "JP PO,nnnn");	print "\t\tJPC(!TSTFLAG(P));\n";
&case(0xE3, "EX (SP),HL");	print "\t\ttemp = HL; POP(HL); PUSH(temp);\n";
&case(0xE4, "CALL PO,nnnn");	print "\t\tCALLC(!TSTFLAG(P));\n";
&case(0xE5, "PUSH HL");		print "\t\tPUSH(HL);\n";
&case(0xE6, "AND nn");		&ANDAl("&", "GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xE7, "RST 20H");		print "\t\tPUSH(PC); PC = 0x20;\n";
&case(0xE8, "RET PE");		print "\t\tif (TSTFLAG(P)) POP(PC);\n";
&case(0xE9, "JP (HL)");		print "\t\tPC = HL;\n";
&case(0xEA, "JP PE,nnnn");	print "\t\tJPC(TSTFLAG(P));\n";
&case(0xEB, "EX DE,HL");	print "\t\ttemp = HL; HL = DE; DE = temp;\n";
&case(0xEC, "CALL PE,nnnn");	print "\t\tCALLC(TSTFLAG(P));\n";
&case(0xED, "ED prefix");	&ED("HL");
&case(0xEE, "XOR nn");		&LOGAl("^", "GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xEF, "RST 28H");		print "\t\tPUSH(PC); PC = 0x28;\n";
&case(0xF0, "RET P");		print "\t\tif (!TSTFLAG(S)) POP(PC);\n";
&case(0xF1, "POP AF");		print "\t\tPOP(AF);\n";
&case(0xF2, "JP P,nnnn");	print "\t\tJPC(!TSTFLAG(S));\n";
&case(0xF3, "DI");		print "\t\tIFF = 0;\n";
&case(0xF4, "CALL P,nnnn");	print "\t\tCALLC(!TSTFLAG(S));\n";
&case(0xF5, "PUSH AF");		print "\t\tPUSH(AF);\n";
&case(0xF6, "OR nn");		&LOGAl("|", "GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xF7, "RST 30H");		print "\t\tPUSH(PC); PC = 0x30;\n";
&case(0xF8, "RET M");		print "\t\tif (TSTFLAG(S)) POP(PC);\n";
&case(0xF9, "LD SP,HL");	print "\t\tSP = HL;\n";
&case(0xFA, "JP M,nnnn");	print "\t\tJPC(TSTFLAG(S));\n";
&case(0xFB, "EI");		print "\t\tIFF = 3;\n";
&case(0xFC, "CALL M,nnnn");	print "\t\tCALLC(TSTFLAG(S));\n";
&case(0xFD, "FD prefix");	$dfd_inline ? &DFD("IY") : &DFD("iy");
&case(0xFE, "CP nn");		&CPAr("GetBYTE(PC)"); print "\t\t++PC;\n";
&case(0xFF, "RST 38H");		print "\t\tPUSH(PC); PC = 0x38;\n";

&postamble;

sub case {
    local($op,$cmnt) = @_;
    if ($needbreak) {
	print $optab ? "${tab}\tcontinue;\n" : "${tab}\tbreak;\n";
    }
    $needbreak = 1;
    printf("${tab}case 0x%02X:\t\t\t/* $cmnt */\n", $op) if !$optab;
    printf("${tab}op_%02x:\t\t\t/* $cmnt */\n", $op) if $optab;
}

sub JRcond {
    local($cond) = @_;
    print "${tab}\tPC += ($cond) ? (signed char) GetBYTE(PC) + 1 : 1;\n";
}

sub LDmemr {
    local($reg,$which) = @_;
    print "${tab}\ttemp = GetWORD(PC);\n";
    print "${tab}\tPutBYTE(temp, ${which}reg($reg));\n";
    if ($combine && $labpcp2) {
	print "${tab}\tgoto labpcp2;\n";
	$needbreak = 0;
    }
    else {
	$labpcp2 = 1;
	print "${tab}labpcp2:\n" if $combine;
	print "${tab}\tPC += 2;\n";
    }
}

sub LDrmem {
    local($reg,$which) = @_;
    print "${tab}\ttemp = GetWORD(PC);\n";
    print "${tab}\tSet${which}reg($reg, GetBYTE(temp));\n";
    if ($combine && $labpcp2) {
	print "${tab}\tgoto labpcp2;\n";
	$needbreak = 0;
    }
    else {
	$labpcp2 = 1;
	print "${tab}labpcp2:\n" if $combine;
	print "${tab}\tPC += 2;\n";
    }
}

sub LDddmem {
    local($reg) = @_;
    print "${tab}\ttemp = GetWORD(PC);\n";
    print "${tab}\t$reg = GetWORD(temp);\n";
    if ($combine && $labpcp2) {
	print "${tab}\tgoto labpcp2;\n";
	$needbreak = 0;
    }
    else {
	$labpcp2 = 1;
	print "${tab}labpcp2:\n" if $combine;
	print "${tab}\tPC += 2;\n";
    }
}

sub LDmemdd {
    local($reg) = @_;
    print "${tab}\ttemp = GetWORD(PC);\n";
    print "${tab}\tPutWORD(temp, $reg);\n";
    if ($combine && $labpcp2) {
	print "${tab}\tgoto labpcp2;\n";
	$needbreak = 0;
    }
    else {
	$labpcp2 = 1;
	print "${tab}labpcp2:\n" if $combine;
	print "${tab}\tPC += 2;\n";
    }
}

sub LDddnn {
    local($reg) = @_;
    print "${tab}\t$reg = GetWORD(PC);\n";
    if ($combine && $labpcp2) {
	print "${tab}\tgoto labpcp2;\n";
	$needbreak = 0;
    }
    else {
	$labpcp2 = 1;
	print "${tab}labpcp2:\n" if $combine;
	print "${tab}\tPC += 2;\n";
    }
}

sub INCr {
    local($reg,$which) = @_;
    if ($which eq "h") {
	print "${tab}\t$reg += 0x100;\n${tab}\ttemp = hreg($reg);\n";
    }
    else {
	print "${tab}\ttemp = ${which}reg($reg)+1;\n${tab}\tSet${which}reg($reg, temp);\n";
    }
    if ($combine && $labincr) {
	print "${tab}\tgoto labincr;\n";
	$needbreak = 0;
    }
    else {
	$labincr = 1;
	print "${tab}labincr:\n" if $combine;
	print <<"EOT";
$tab	AF = (AF & ~0xfe) | (temp & 0xa8) |
$tab		(((temp & 0xff) == 0) << 6) |
$tab		(((temp & 0xf) == 0) << 4) |
$tab		((temp == 0x80) << 2);
EOT
    }
}

sub INCm {
    local($reg) = @_;
    print "${tab}\ttemp = GetBYTE($reg)+1;\n${tab}\tPutBYTE($reg, temp);\n";
    if ($combine && $labincr) {
	print "${tab}\tgoto labincr;\n";
	$needbreak = 0;
    }
    else {
	$labincr = 1;
	print "${tab}labincr:\n" if $combine;
	print <<"EOT";
$tab	AF = (AF & ~0xfe) | (temp & 0xa8) |
$tab		(((temp & 0xff) == 0) << 6) |
$tab		(((temp & 0xf) == 0) << 4) |
$tab		((temp == 0x80) << 2);
EOT
    }
}

sub DECr {
    local($reg,$which) = @_;
    if ($which eq "h") {
	print "${tab}\t$reg -= 0x100;\n${tab}\ttemp = hreg($reg);\n";
    }
    else {
	print "${tab}\ttemp = ${which}reg($reg)-1;\n${tab}\tSet${which}reg($reg, temp);\n";
    }
    if ($combine && $labdecr) {
	print "${tab}\tgoto labdecr;\n";
	$needbreak = 0;
    }
    else {
	$labdecr = 1;
	print "${tab}labdecr:\n" if $combine;
	print <<"EOT";
$tab	AF = (AF & ~0xfe) | (temp & 0xa8) |
$tab		(((temp & 0xff) == 0) << 6) |
$tab		(((temp & 0xf) == 0xf) << 4) |
$tab		((temp == 0x7f) << 2) | 2;
EOT
    }
}

sub DECm {
    local($reg) = @_;
    print "${tab}\ttemp = GetBYTE($reg)-1;\n${tab}\tPutBYTE($reg, temp);\n";
    if ($combine && $labdecr) {
	print "${tab}\tgoto labdecr;\n";
	$needbreak = 0;
    }
    else {
	$labdecr = 1;
	print "${tab}labdecr:\n" if $combine;
	print <<"EOT";
$tab	AF = (AF & ~0xfe) | (temp & 0xa8) |
$tab		(((temp & 0xff) == 0) << 6) |
$tab		(((temp & 0xf) == 0xf) << 4) |
$tab		((temp == 0x7f) << 2) | 2;
EOT
    }
}

sub ADDAr {
    local($val) = @_;
    print "${tab}\ttemp = $val;\n";
    if ($combine && $labaddar) {
	print "${tab}\tgoto labaddar;\n";
	$needbreak = 0;
    }
    else {
	$labaddar = 1;
		print "${tab}labaddar:\n" if $combine;
		print <<"EOT";
$tab	acu = hreg(AF);
$tab	sum = acu + temp;
$tab	cbits = acu ^ temp ^ sum;
$tab	AF = ((sum & 0xff) << 8) | (sum & 0xa8) |
$tab		(((sum & 0xff) == 0) << 6) | (cbits & 0x10) |
$tab		(((cbits >> 6) ^ (cbits >> 5)) & 4) |
$tab		((cbits >> 8) & 1);
EOT
    }
}

sub ADCAr {
    local($val) = @_;
    print "${tab}\ttemp = $val;\n";
    if ($combine && $labadcar) {
	print "${tab}\tgoto labadcar;\n";
	$needbreak = 0;
    }
    else {
	$labadcar = 1;
		print "${tab}labadcar:\n" if $combine;
		print <<"EOT";
$tab	acu = hreg(AF);
$tab	sum = acu + temp + TSTFLAG(C);
$tab	cbits = acu ^ temp ^ sum;
$tab	AF = ((sum & 0xff) << 8) | (sum & 0xa8) |
$tab		(((sum & 0xff) == 0) << 6) | (cbits & 0x10) |
$tab		(((cbits >> 6) ^ (cbits >> 5)) & 4) |
$tab		((cbits >> 8) & 1);
EOT
    }
}

sub SUBAr {
    local($val) = @_;
    print "${tab}\ttemp = $val;\n";
    if ($combine && $labsubar) {
	print "${tab}\tgoto labsubar;\n";
	$needbreak = 0;
    }
    else {
	$labsubar = 1;
		print "${tab}labsubar:\n" if $combine;
		print <<"EOT";
$tab	acu = hreg(AF);
$tab	sum = acu - temp;
$tab	cbits = acu ^ temp ^ sum;
$tab	AF = ((sum & 0xff) << 8) | (sum & 0xa8) |
$tab		(((sum & 0xff) == 0) << 6) | (cbits & 0x10) |
$tab		(((cbits >> 6) ^ (cbits >> 5)) & 4) | 2 |
$tab		((cbits >> 8) & 1);
EOT
    }
}

sub SBCAr {
    local($val) = @_;
    print "${tab}\ttemp = $val;\n";
    if ($combine && $labsbcar) {
	print "${tab}\tgoto labsbcar;\n";
	$needbreak = 0;
    }
    else {
	$labsbcar = 1;
	print "${tab}labsbcar:\n" if $combine;
	print <<"EOT";
$tab	acu = hreg(AF);
$tab	sum = acu - temp - TSTFLAG(C);
$tab	cbits = acu ^ temp ^ sum;
$tab	AF = ((sum & 0xff) << 8) | (sum & 0xa8) |
$tab		(((sum & 0xff) == 0) << 6) | (cbits & 0x10) |
$tab		(((cbits >> 6) ^ (cbits >> 5)) & 4) | 2 |
$tab		((cbits >> 8) & 1);
EOT
    }
}

sub ANDAh {
    local($op, $reg) = @_;
    print "${tab}\tsum = ((AF $op ($reg)) >> 8) & 0xff;\n";
    if ($combine && $labandar) {
	print "${tab}\tgoto labandar;\n";
	$needbreak = 0;
    }
    else {
	$labandar = 1;
	print "${tab}labandar:\n" if $combine;
	print "${tab}\tAF = (sum << 8) | (sum & 0xa8) |\n";
	print "${tab}\t\t((sum == 0) << 6) | 0x10 | partab[sum];\n";
    }
}

sub ANDAl {
    local($op, $reg) = @_;
    print "${tab}\tsum = ((AF >> 8) $op $reg) & 0xff;\n";
    if ($combine && $labandar) {
	print "${tab}\tgoto labandar;\n";
	$needbreak = 0;
    }
    else {
	$labandar = 1;
	print "${tab}labandar:\n" if $combine;
	print "${tab}\tAF = (sum << 8) | (sum & 0xa8) | 0x10 |\n";
	print "${tab}\t\t((sum == 0) << 6) | partab[sum];\n";
    }
}

sub LOGAh {
    local($op, $reg) = @_;
    print "${tab}\tsum = ((AF $op ($reg)) >> 8) & 0xff;\n";
    if ($combine && $lablogar) {
	print "${tab}\tgoto lablogar;\n";
	$needbreak = 0;
    }
    else {
	$lablogar = 1;
	print "${tab}lablogar:\n" if $combine;
	print
"${tab}\tAF = (sum << 8) | (sum & 0xa8) | ((sum == 0) << 6) | partab[sum];\n";
    }
}

sub LOGAl {
    local($op, $reg) = @_;
    print "${tab}\tsum = ((AF >> 8) $op $reg) & 0xff;\n";
    if ($combine && $lablogar) {
	print "${tab}\tgoto lablogar;\n";
	$needbreak = 0;
    }
    else {
	$lablogar = 1;
	print "${tab}lablogar:\n" if $combine;
	print
"${tab}\tAF = (sum << 8) | (sum & 0xa8) | ((sum == 0) << 6) | partab[sum];\n";
    }
}

sub CPAr {
    local($reg) = @_;
    print "${tab}\ttemp = $reg;\n";
    print "${tab}\tAF = (AF & ~0x28) | (temp & 0x28);\n";
    if ($combine && $labcpar) {
	print "${tab}\tgoto labcpar;\n";
	$needbreak = 0;
    }
    else {
	$labcpar = 1;
	print "${tab}labcpar:\n" if $combine;
	print <<"EOT";
$tab	acu = hreg(AF);
$tab	sum = acu - temp;
$tab	cbits = acu ^ temp ^ sum;
$tab	AF = (AF & ~0xff) | (sum & 0x80) |
$tab		(((sum & 0xff) == 0) << 6) | (temp & 0x28) |
$tab		(((cbits >> 6) ^ (cbits >> 5)) & 4) | 2 |
$tab		(cbits & 0x10) | ((cbits >> 8) & 1);
EOT
    }
}

sub ADDdd {
    local($r1,$r2) = @_;
    print "${tab}\t$r1 &= 0xffff;\n" if ($r1 ne $r2);
    print <<"EOT";
$tab	$r2 &= 0xffff;
$tab	sum = $r1 + $r2;
$tab	cbits = ($r1 ^ $r2 ^ sum) >> 8;
$tab	$r1 = sum;
EOT
    if ($combine && $labadddd) {
	print "${tab}\tgoto labadddd;\n";
	$needbreak = 0;
    }
    else {
	$labadddd = 1;
	print "${tab}labadddd:\n" if $combine;
	print <<"EOT";
$tab	AF = (AF & ~0x3b) | ((sum >> 8) & 0x28) |
$tab		(cbits & 0x10) | ((cbits >> 8) & 1);
EOT
    }
}

sub ADCdd {
    local($r1,$r2) = @_;
    print "${tab}\t$r1 &= 0xffff;\n" if ($r1 ne $r2);
    print <<"EOT";
$tab	$r2 &= 0xffff;
$tab	sum = $r1 + $r2 + TSTFLAG(C);
$tab	cbits = ($r1 ^ $r2 ^ sum) >> 8;
$tab	$r1 = sum;
EOT
    if ($combine && $labadcdd) {
	print "${tab}\tgoto labadcdd;\n";
	$needbreak = 0;
    }
    else {
	$labadcdd = 1;
	print "${tab}labadcdd:\n" if $combine;
	print <<"EOT";
$tab	AF = (AF & ~0xff) | ((sum >> 8) & 0xa8) |
$tab		(((sum & 0xffff) == 0) << 6) |
$tab		(((cbits >> 6) ^ (cbits >> 5)) & 4) |
$tab		(cbits & 0x10) | ((cbits >> 8) & 1);
EOT
    }
}

sub SBCdd {
    local($r1,$r2) = @_;
    print "${tab}\t$r1 &= 0xffff;\n" if ($r1 ne $r2);
    print <<"EOT";
$tab	$r2 &= 0xffff;
$tab	sum = $r1 - $r2 - TSTFLAG(C);
$tab	cbits = ($r1 ^ $r2 ^ sum) >> 8;
$tab	$r1 = sum;
EOT
    if ($combine && $labsbcdd) {
	print "${tab}\tgoto labsbcdd;\n";
	$needbreak = 0;
    }
    else {
	$labsbcdd = 1;
	print "${tab}labsbcdd:\n" if $combine;
	print <<"EOT";
$tab	AF = (AF & ~0xff) | ((sum >> 8) & 0xa8) |
$tab		(((sum & 0xffff) == 0) << 6) |
$tab		(((cbits >> 6) ^ (cbits >> 5)) & 4) |
$tab		(cbits & 0x10) | 2 | ((cbits >> 8) & 1);
EOT
    }
}

sub INP {
    local($reg,$which) = @_;
    print <<"EOT";
$tab	temp = Input(lreg(BC));
$tab	Set${which}reg($reg, temp);
$tab	AF = (AF & ~0xfe) | (temp & 0xa8) |
$tab		(((temp & 0xff) == 0) << 6) |
$tab		parity(temp);
EOT
}

sub OUTP {
    local($reg,$which) = @_;
    print <<"EOT";
$tab	Output(lreg(BC), $reg);
EOT
}

sub CB {
    local($reg) = @_;
    if ($cb_inline) {
	print "${tab}\tadr = $reg;\n";
	&cb_switch;
    }
    else {
	print <<"EOT";
$tab	SAVE_STATE();
$tab	cb_prefix($reg);
$tab	LOAD_STATE();
EOT
    }
}

sub cb_switch {
    local($optabsav) = $optab;
    $optab = 0;
    $cblabno += 1;
    print <<"EOT";
$tab	switch ((op = GetBYTE(PC)) & 7) {
$tab	case 0: ++PC; acu = hreg(BC); break;
$tab	case 1: ++PC; acu = lreg(BC); break;
$tab	case 2: ++PC; acu = hreg(DE); break;
$tab	case 3: ++PC; acu = lreg(DE); break;
$tab	case 4: ++PC; acu = hreg(HL); break;
$tab	case 5: ++PC; acu = lreg(HL); break;
$tab	case 6: ++PC; acu = GetBYTE(adr);  break;
$tab	case 7: ++PC; acu = hreg(AF); break;
$tab	}
$tab	switch (op & 0xc0) {
$tab	case 0x00:		/* shift/rotate */
$tab		switch (op & 0x38) {
$tab		case 0x00:	/* RLC */
$tab			temp = (acu << 1) | (acu >> 7);
$tab			cbits = temp & 1;
$tab			goto cbshflg$cblabno;
$tab		case 0x08:	/* RRC */
$tab			temp = (acu >> 1) | (acu << 7);
$tab			cbits = temp & 0x80;
$tab			goto cbshflg$cblabno;
$tab		case 0x10:	/* RL */
$tab			temp = (acu << 1) | TSTFLAG(C);
$tab			cbits = acu & 0x80;
$tab			goto cbshflg$cblabno;
$tab		case 0x18:	/* RR */
$tab			temp = (acu >> 1) | (TSTFLAG(C) << 7);
$tab			cbits = acu & 1;
$tab			goto cbshflg$cblabno;
$tab		case 0x20:	/* SLA */
$tab			temp = acu << 1;
$tab			cbits = acu & 0x80;
$tab			goto cbshflg$cblabno;
$tab		case 0x28:	/* SRA */
$tab			temp = (acu >> 1) | (acu & 0x80);
$tab			cbits = acu & 1;
$tab			goto cbshflg$cblabno;
$tab		case 0x30:	/* SLIA */
$tab			temp = (acu << 1) | 1;
$tab			cbits = acu & 0x80;
$tab			goto cbshflg$cblabno;
$tab		case 0x38:	/* SRL */
$tab			temp = acu >> 1;
$tab			cbits = acu & 1;
$tab		cbshflg$cblabno:
$tab			AF = (AF & ~0xff) | (temp & 0xa8) |
$tab				(((temp & 0xff) == 0) << 6) |
$tab				parity(temp) | !!cbits;
$tab		}
$tab		break;
$tab	case 0x40:		/* BIT */
$tab		if (acu & (1 << ((op >> 3) & 7)))
$tab			AF = (AF & ~0xfe) | 0x10 |
$tab			(((op & 0x38) == 0x38) << 7);
$tab		else
$tab			AF = (AF & ~0xfe) | 0x54;
$tab		if ((op&7) != 6)
$tab			AF |= (acu & 0x28);
$tab		temp = acu;
$tab		break;
$tab	case 0x80:		/* RES */
$tab		temp = acu & ~(1 << ((op >> 3) & 7));
$tab		break;
$tab	case 0xc0:		/* SET */
$tab		temp = acu | (1 << ((op >> 3) & 7));
$tab		break;
$tab	}
$tab	switch (op & 7) {
$tab	case 0: Sethreg(BC, temp); break;
$tab	case 1: Setlreg(BC, temp); break;
$tab	case 2: Sethreg(DE, temp); break;
$tab	case 3: Setlreg(DE, temp); break;
$tab	case 4: Sethreg(HL, temp); break;
$tab	case 5: Setlreg(HL, temp); break;
$tab	case 6: PutBYTE(adr, temp);  break;
$tab	case 7: Sethreg(AF, temp); break;
$tab	}
EOT
    $optab = $optabsav;
}


sub DFD {
    local($reg) = @_;
    if ($dfd_inline) {
	&dfd_switch($reg);
    }
    else {
	print <<"EOT";
$tab	SAVE_STATE();
$tab	$reg = dfd_prefix($reg);
$tab	LOAD_STATE();
EOT
    }
}

sub Offsadr {
    local($reg) = @_;
    print "${tab}\tadr = $reg + (signed char) GetBYTE(PC); ++PC;\n";
}

sub dfd_switch {
    local($reg) = @_;
    local($optabsav) = $optab;
    $optab = 0;
    print "${tab}\tswitch (++PC, op = GetBYTE(PC-1)) {\n";
    $tab = "\t\t";
    $needbreak = 0;
    &case(0x09, "ADD $reg,BC");		&ADDdd($reg, BC);
    &case(0x19, "ADD $reg,DE");		&ADDdd($reg, DE);
    &case(0x21, "LD $reg,nnnn");	&LDddnn($reg);
    &case(0x22, "LD (nnnn),$reg");	&LDmemdd($reg);
    &case(0x23, "INC $reg");		print "${tab}\t++$reg;\n";
    &case(0x24, "INC ${reg}H");		&INCr($reg, "h");
    &case(0x25, "DEC ${reg}H");		&DECr($reg, "h");
    &case(0x26, "LD ${reg}H,nn");	print "${tab}\tSethreg($reg, GetBYTE(PC)); ++PC;\n";
    &case(0x29, "ADD $reg,$reg");	&ADDdd($reg, $reg);
    &case(0x2A, "LD $reg,(nnnn)");	&LDddmem($reg);
    &case(0x2B, "DEC $reg");		print "${tab}\t--$reg;\n";
    &case(0x2C, "INC ${reg}L");		&INCr($reg, "l");
    &case(0x2D, "DEC ${reg}L");		&DECr($reg, "l");
    &case(0x2E, "LD ${reg}L,nn");	print "${tab}\tSetlreg($reg, GetBYTE(PC)); ++PC;\n";
    &case(0x34, "INC ($reg+dd)");	&Offsadr($reg); &INCm("adr");
    &case(0x35, "DEC ($reg+dd)");	&Offsadr($reg); &DECm("adr");
    &case(0x36, "LD ($reg+dd),nn");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, GetBYTE(PC)); ++PC;\n";
    &case(0x39, "ADD $reg,SP");		&ADDdd($reg, SP);
    &case(0x44, "LD B,${reg}H");	print "${tab}\tSethreg(BC, hreg($reg));\n";
    &case(0x45, "LD B,${reg}L");	print "${tab}\tSethreg(BC, lreg($reg));\n";
    &case(0x46, "LD B,($reg+dd)");	&Offsadr($reg); print "${tab}\tSethreg(BC, GetBYTE(adr));\n";
    &case(0x4C, "LD C,${reg}H");	print "${tab}\tSetlreg(BC, hreg($reg));\n";
    &case(0x4D, "LD C,${reg}L");	print "${tab}\tSetlreg(BC, lreg($reg));\n";
    &case(0x4E, "LD C,($reg+dd)");	&Offsadr($reg); print "${tab}\tSetlreg(BC, GetBYTE(adr));\n";
    &case(0x54, "LD D,${reg}H");	print "${tab}\tSethreg(DE, hreg($reg));\n";
    &case(0x55, "LD D,${reg}L");	print "${tab}\tSethreg(DE, lreg($reg));\n";
    &case(0x56, "LD D,($reg+dd)");	&Offsadr($reg); print "${tab}\tSethreg(DE, GetBYTE(adr));\n";
    &case(0x5C, "LD E,H");		print "${tab}\tSetlreg(DE, hreg($reg));\n";
    &case(0x5D, "LD E,L");		print "${tab}\tSetlreg(DE, lreg($reg));\n";
    &case(0x5E, "LD E,($reg+dd)");	&Offsadr($reg); print "${tab}\tSetlreg(DE, GetBYTE(adr));\n";
    &case(0x60, "LD ${reg}H,B");	print "${tab}\tSethreg($reg, hreg(BC));\n";
    &case(0x61, "LD ${reg}H,C");	print "${tab}\tSethreg($reg, lreg(BC));\n";
    &case(0x62, "LD ${reg}H,D");	print "${tab}\tSethreg($reg, hreg(DE));\n";
    &case(0x63, "LD ${reg}H,E");	print "${tab}\tSethreg($reg, lreg(DE));\n";
    &case(0x64, "LD ${reg}H,${reg}H");	print "${tab}\t/* nop */\n";
    &case(0x65, "LD ${reg}H,${reg}L");	print "${tab}\tSethreg($reg, lreg($reg));\n";
    &case(0x66, "LD H,($reg+dd)");	&Offsadr($reg); print "${tab}\tSethreg(HL, GetBYTE(adr));\n";
    &case(0x67, "LD ${reg}H,A");	print "${tab}\tSethreg($reg, hreg(AF));\n";
    &case(0x68, "LD ${reg}L,B");	print "${tab}\tSetlreg($reg, hreg(BC));\n";
    &case(0x69, "LD ${reg}L,C");	print "${tab}\tSetlreg($reg, lreg(BC));\n";
    &case(0x6A, "LD ${reg}L,D");	print "${tab}\tSetlreg($reg, hreg(DE));\n";
    &case(0x6B, "LD ${reg}L,E");	print "${tab}\tSetlreg($reg, lreg(DE));\n";
    &case(0x6C, "LD ${reg}L,${reg}H");	print "${tab}\tSetlreg($reg, hreg($reg));\n";
    &case(0x6D, "LD ${reg}L,${reg}L");	print "${tab}\t/* nop */\n";
    &case(0x6E, "LD L,($reg+dd)");	&Offsadr($reg); print "${tab}\tSetlreg(HL, GetBYTE(adr));\n";
    &case(0x6F, "LD ${reg}L,A");	print "${tab}\tSetlreg($reg, hreg(AF));\n";
    &case(0x70, "LD ($reg+dd),B");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, hreg(BC));\n";
    &case(0x71, "LD ($reg+dd),C");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, lreg(BC));\n";
    &case(0x72, "LD ($reg+dd),D");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, hreg(DE));\n";
    &case(0x73, "LD ($reg+dd),E");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, lreg(DE));\n";
    &case(0x74, "LD ($reg+dd),H");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, hreg(HL));\n";
    &case(0x75, "LD ($reg+dd),L");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, lreg(HL));\n";
    &case(0x77, "LD ($reg+dd),A");	&Offsadr($reg); print "${tab}\tPutBYTE(adr, hreg(AF));\n";
    &case(0x7C, "LD A,${reg}H");	print "${tab}\tSethreg(AF, hreg($reg));\n";
    &case(0x7D, "LD A,${reg}L");	print "${tab}\tSethreg(AF, lreg($reg));\n";
    &case(0x7E, "LD A,($reg+dd)");	&Offsadr($reg); print "${tab}\tSethreg(AF, GetBYTE(adr));\n";
    &case(0x84, "ADD A,${reg}H");	&ADDAr("hreg($reg)");
    &case(0x85, "ADD A,${reg}L");	&ADDAr("lreg($reg)");
    &case(0x86, "ADD A,($reg+dd)");	&Offsadr($reg); &ADDAr("GetBYTE(adr)");
    &case(0x8C, "ADC A,${reg}H");	&ADCAr("hreg($reg)");
    &case(0x8D, "ADC A,${reg}L");	&ADCAr("lreg($reg)");
    &case(0x8E, "ADC A,($reg+dd)");	&Offsadr($reg); &ADCAr("GetBYTE(adr)");
    &case(0x94, "SUB ${reg}H");		&SUBAr("hreg($reg)");
    &case(0x95, "SUB ${reg}L");		&SUBAr("lreg($reg)");
    &case(0x96, "SUB ($reg+dd)");	&Offsadr($reg); &SUBAr("GetBYTE(adr)");
    &case(0x9C, "SBC A,${reg}H");	&SBCAr("hreg($reg)");
    &case(0x9D, "SBC A,${reg}L");	&SBCAr("lreg($reg)");
    &case(0x9E, "SBC A,($reg+dd)");	&Offsadr($reg); &SBCAr("GetBYTE(adr)");
    &case(0xA4, "AND ${reg}H");		&ANDAh("&", "$reg");
    &case(0xA5, "AND ${reg}L");		&ANDAl("&", "$reg");
    &case(0xA6, "AND ($reg+dd)");	&Offsadr($reg); &ANDAl("&", "GetBYTE(adr)");
    &case(0xAC, "XOR ${reg}H");		&LOGAh("^", "$reg");
    &case(0xAD, "XOR ${reg}L");		&LOGAl("^", "$reg");
    &case(0xAE, "XOR ($reg+dd)");	&Offsadr($reg); &LOGAl("^", "GetBYTE(adr)");
    &case(0xB4, "OR ${reg}H");		&LOGAh("|", "$reg");
    &case(0xB5, "OR ${reg}L");		&LOGAl("|", "$reg");
    &case(0xB6, "OR ($reg+dd)");	&Offsadr($reg); &LOGAl("|", "GetBYTE(adr)");
    &case(0xBC, "CP ${reg}H");		&CPAr("hreg($reg)");
    &case(0xBD, "CP ${reg}L");		&CPAr("lreg($reg)");
    &case(0xBE, "CP ($reg+dd)");	&Offsadr($reg); &CPAr("GetBYTE(adr)");
    &case(0xCB, "CB prefix");		&Offsadr($reg); &CB("adr");
    &case(0xE1, "POP $reg");		print "${tab}\tPOP($reg);\n";
    &case(0xE3, "EX (SP),$reg");	print "${tab}\ttemp = $reg; POP($reg); PUSH(temp);\n";
    &case(0xE5, "PUSH $reg");		print "${tab}\tPUSH($reg);\n";
    &case(0xE9, "JP ($reg)");		print "${tab}\tPC = $reg;\n";
    &case(0xF9, "LD SP,$reg");		print "${tab}\tSP = $reg;\n";
    print "${tab}\tbreak;\n${tab}default: PC--;\t\t/* ignore DD */\n";
    print "${tab}}\n";
    $tab = "\t";
    $optab = $optabsav;
}

sub ED {
    local($reg) = @_;
    if ($ed_inline) {
	&ed_switch;
    }
    else {
	print <<"EOT";
$tab	SAVE_STATE();
$tab	ed_prefix();
$tab	LOAD_STATE();
EOT
    }
}

sub ed_switch {
    local($optabsav) = $optab;
    $optab = 0;
    print "${tab}\tswitch (++PC, op = GetBYTE(PC-1)) {\n";
    $tab = "\t\t";
    $needbreak = 0;
    &case(0x40, "IN B,(C)");		&INP(BC, "h");
    &case(0x41, "OUT (C),B");		&OUTP(BC, "h");
    &case(0x42, "SBC HL,BC");		&SBCdd(HL, BC);
    &case(0x43, "LD (nnnn),BC");	&LDmemdd(BC);
    &case(0x44, "NEG");			print <<"EOT";
			temp = hreg(AF);
			AF = (-(AF & 0xff00) & 0xff00);
			AF |= ((AF >> 8) & 0xa8) | (((AF & 0xff00) == 0) << 6) |
				(((temp & 0x0f) != 0) << 4) | ((temp == 0x80) << 2) |
				2 | (temp != 0);
EOT
    &case(0x45, "RETN");		print "\t\t\tIFF |= IFF >> 1;\n\t\t\tPOP(PC);\n";
    &case(0x46, "IM 0");		print "\t\t\t/* interrupt mode 0 */\n";
    &case(0x47, "LD I,A");		print "\t\t\tir = (ir & 255) | (AF & ~255);\n";
    &case(0x48, "IN C,(C)");		&INP(BC, "l");
    &case(0x49, "OUT (C),C");		&OUTP(BC, "l");
    &case(0x4A, "ADC HL,BC");		&ADCdd(HL, BC);
    &case(0x4B, "LD BC,(nnnn)");	&LDddmem(BC);
    &case(0x4D, "RETI");		print "\t\t\tIFF |= IFF >> 1;\n\t\t\tPOP(PC);\n";
    &case(0x4F, "LD R,A");		print "\t\t\tir = (ir & ~255) | ((AF >> 8) & 255);\n";
    &case(0x50, "IN D,(C)");		&INP(DE, "h");
    &case(0x51, "OUT (C),D");		&OUTP(DE, "h");
    &case(0x52, "SBC HL,DE");		&SBCdd(HL, DE);
    &case(0x53, "LD (nnnn),DE");	&LDmemdd(DE);
    &case(0x56, "IM 1");		print "\t\t\t/* interrupt mode 1 */\n";
    &case(0x57, "LD A,I");		print "\t\t\tAF = (AF & 0x29) | (ir & ~255) | ",
					      "((ir >> 8) & 0x80) | (((ir & ~255) == 0) << 6)",
					      " | ((IFF & 2) << 1);\n";
    &case(0x58, "IN E,(C)");		&INP(DE, "l");
    &case(0x59, "OUT (C),E");		&OUTP(DE, "l");
    &case(0x5A, "ADC HL,DE");		&ADCdd(HL, DE);
    &case(0x5B, "LD DE,(nnnn)");	&LDddmem(DE);
    &case(0x5E, "IM 2");		print "\t\t\t/* interrupt mode 2 */\n";
    &case(0x5F, "LD A,R");		print "\t\t\tAF = (AF & 0x29) | ((ir & 255) << 8) | ",
					      "(ir & 0x80) | (((ir & 255) == 0) << 6)",
					      " | ((IFF & 2) << 1);\n";
    &case(0x60, "IN H,(C)");		&INP(HL, "h");
    &case(0x61, "OUT (C),H");		&OUTP(HL, "h");
    &case(0x62, "SBC HL,HL");		&SBCdd(HL, HL);
    &case(0x63, "LD (nnnn),HL");	&LDmemdd(HL);
    &case(0x67, "RRD");			print <<"EOT";
			temp = GetBYTE(HL);
			acu = hreg(AF);
			PutBYTE(HL, hdig(temp) | (ldig(acu) << 4));
			acu = (acu & 0xf0) | ldig(temp);
			AF = (acu << 8) | (acu & 0xa8) | (((acu & 0xff) == 0) << 6) |
				partab[acu] | (AF & 1);
EOT
    &case(0x68, "IN L,(C)");		&INP(HL, "l");
    &case(0x69, "OUT (C),L");		&OUTP(HL, "l");
    &case(0x6A, "ADC HL,HL");		&ADCdd(HL, HL);
    &case(0x6B, "LD HL,(nnnn)");	&LDddmem(HL);
    &case(0x6F, "RLD");			print <<"EOT";
			temp = GetBYTE(HL);
			acu = hreg(AF);
			PutBYTE(HL, (ldig(temp) << 4) | ldig(acu));
			acu = (acu & 0xf0) | hdig(temp);
			AF = (acu << 8) | (acu & 0xa8) | (((acu & 0xff) == 0) << 6) |
				partab[acu] | (AF & 1);
EOT
    &case(0x70, "IN (C)");		&INP("temp", "l");
    &case(0x71, "OUT (C),0");		&OUTP(0, "l");
    &case(0x72, "SBC HL,SP");		&SBCdd(HL, SP);
    &case(0x73, "LD (nnnn),SP");	&LDmemdd(SP);
    &case(0x78, "IN A,(C)");		&INP(AF, "h");
    &case(0x79, "OUT (C),A");		&OUTP(AF, "h");
    &case(0x7A, "ADC HL,SP");		&ADCdd(HL, SP);
    &case(0x7B, "LD SP,(nnnn)");	&LDddmem(SP);
    &case(0xA0, "LDI");			print <<"EOT";
			acu = GetBYTE(HL); ++HL;
			PutBYTE(DE, acu); ++DE;
			acu += hreg(AF);
			AF = (AF & ~0x3e) | (acu & 8) | ((acu & 2) << 4) |
				(((--BC & 0xffff) != 0) << 2);
EOT
    &case(0xA1, "CPI");			print <<"EOT";
			acu = hreg(AF);
			temp = GetBYTE(HL); ++HL;
			sum = acu - temp;
			cbits = acu ^ temp ^ sum;
			AF = (AF & ~0xfe) | (sum & 0x80) | (!(sum & 0xff) << 6) |
				(((sum - ((cbits&16)>>4))&2) << 4) | (cbits & 16) |
				((sum - ((cbits >> 4) & 1)) & 8) |
				((--BC & 0xffff) != 0) << 2 | 2;
			if ((sum & 15) == 8 && (cbits & 16) != 0)
				AF &= ~8;
EOT
    &case(0xA2, "INI");			print <<"EOT";
			PutBYTE(HL, Input(lreg(BC))); ++HL;
			SETFLAG(N, 1);
			SETFLAG(P, (--BC & 0xffff) != 0);
EOT
    &case(0xA3, "OUTI");		print <<"EOT";
			Output(lreg(BC), GetBYTE(HL)); ++HL;
			SETFLAG(N, 1);
			Sethreg(BC, lreg(BC) - 1);
			SETFLAG(Z, lreg(BC) == 0);
EOT
    &case(0xA8, "LDD");			print <<"EOT";
			acu = GetBYTE(HL); --HL;
			PutBYTE(DE, acu); --DE;
			acu += hreg(AF);
			AF = (AF & ~0x3e) | (acu & 8) | ((acu & 2) << 4) |
				(((--BC & 0xffff) != 0) << 2);
EOT
    &case(0xA9, "CPD");			print <<"EOT";
			acu = hreg(AF);
			temp = GetBYTE(HL); --HL;
			sum = acu - temp;
			cbits = acu ^ temp ^ sum;
			AF = (AF & ~0xfe) | (sum & 0x80) | (!(sum & 0xff) << 6) |
				(((sum - ((cbits&16)>>4))&2) << 4) | (cbits & 16) |
				((sum - ((cbits >> 4) & 1)) & 8) |
				((--BC & 0xffff) != 0) << 2 | 2;
			if ((sum & 15) == 8 && (cbits & 16) != 0)
				AF &= ~8;
EOT
    &case(0xAA, "IND");			print <<"EOT";
			PutBYTE(HL, Input(lreg(BC))); --HL;
			SETFLAG(N, 1);
			Sethreg(BC, lreg(BC) - 1);
			SETFLAG(Z, lreg(BC) == 0);
EOT
    &case(0xAB, "OUTD");		print <<"EOT";
			Output(lreg(BC), GetBYTE(HL)); --HL;
			SETFLAG(N, 1);
			Sethreg(BC, lreg(BC) - 1);
			SETFLAG(Z, lreg(BC) == 0);
EOT
    &case(0xB0, "LDIR");		print <<"EOT";
			acu = hreg(AF);
			BC &= 0xffff;
			do {
				acu = GetBYTE(HL); ++HL;
				PutBYTE(DE, acu); ++DE;
			} while (--BC);
			acu += hreg(AF);
			AF = (AF & ~0x3e) | (acu & 8) | ((acu & 2) << 4);
EOT
    &case(0xB1, "CPIR");		print <<"EOT";
			acu = hreg(AF);
			BC &= 0xffff;
			do {
				temp = GetBYTE(HL); ++HL;
				op = --BC != 0;
				sum = acu - temp;
			} while (op && sum != 0);
			cbits = acu ^ temp ^ sum;
			AF = (AF & ~0xfe) | (sum & 0x80) | (!(sum & 0xff) << 6) |
				(((sum - ((cbits&16)>>4))&2) << 4) |
				(cbits & 16) | ((sum - ((cbits >> 4) & 1)) & 8) |
				op << 2 | 2;
			if ((sum & 15) == 8 && (cbits & 16) != 0)
				AF &= ~8;
EOT
    &case(0xB2, "INIR");		print <<"EOT";
			temp = hreg(BC);
			do {
				PutBYTE(HL, Input(lreg(BC))); ++HL;
			} while (--temp);
			Sethreg(BC, 0);
			SETFLAG(N, 1);
			SETFLAG(Z, 1);
EOT
    &case(0xB3, "OTIR");		print <<"EOT";
			temp = hreg(BC);
			do {
				Output(lreg(BC), GetBYTE(HL)); ++HL;
			} while (--temp);
			Sethreg(BC, 0);
			SETFLAG(N, 1);
			SETFLAG(Z, 1);
EOT
    &case(0xB8, "LDDR");		print <<"EOT";
			BC &= 0xffff;
			do {
				acu = GetBYTE(HL); --HL;
				PutBYTE(DE, acu); --DE;
			} while (--BC);
			acu += hreg(AF);
			AF = (AF & ~0x3e) | (acu & 8) | ((acu & 2) << 4);
EOT
    &case(0xB9, "CPDR");		print <<"EOT";
			acu = hreg(AF);
			BC &= 0xffff;
			do {
				temp = GetBYTE(HL); --HL;
				op = --BC != 0;
				sum = acu - temp;
			} while (op && sum != 0);
			cbits = acu ^ temp ^ sum;
			AF = (AF & ~0xfe) | (sum & 0x80) | (!(sum & 0xff) << 6) |
				(((sum - ((cbits&16)>>4))&2) << 4) |
				(cbits & 16) | ((sum - ((cbits >> 4) & 1)) & 8) |
				op << 2 | 2;
			if ((sum & 15) == 8 && (cbits & 16) != 0)
				AF &= ~8;
EOT
    &case(0xBA, "INDR");		print <<"EOT";
			temp = hreg(BC);
			do {
				PutBYTE(HL, Input(lreg(BC))); --HL;
			} while (--temp);
			Sethreg(BC, 0);
			SETFLAG(N, 1);
			SETFLAG(Z, 1);
EOT
    &case(0xBB, "OTDR");		print <<"EOT";
			temp = hreg(BC);
			do {
				Output(lreg(BC), GetBYTE(HL)); --HL;
			} while (--temp);
			Sethreg(BC, 0);
			SETFLAG(N, 1);
			SETFLAG(Z, 1);
EOT
    print "${tab}\tbreak;\n${tab}default: if (0x40 <= op && op <= 0x7f) PC--;\t\t/* ignore ED */\n";
    print "${tab}}\n";
    $tab = "\t";
    $optab = $optabsav;
}

sub reslabs {
    $labpcp2 = 0;
    $labcpar = 0;
    $lablogar = 0;
    $labandar = 0;
    $labsbcar = 0;
    $labsubar = 0;
    $labadcar = 0;
    $labaddar = 0;
    $labadddd = 0;
    $labdecr = 0;
    $labincr = 0;
}


sub preamble {
    print "#include \"simz80.h\"\n\n";

    print "static const unsigned char partab[256] = {\n";
    for (0..255) {
	print "\t" if (($_ & 15) == 0);
	$x = ($_>>4) ^ ($_&15);
	$x = ($x>>2) ^ ($x&3);
	$x = ($x>>1) ^ ($x&1);
	print $x ? "0," : "4,";
	print "\n" if (($_ & 15) == 15);
    }
    print <<'EOT';
};

#define parity(x)	partab[(x)&0xff]

#ifdef DEBUG
volatile int stopsim;
#endif

#define POP(x)	do {							\
	FASTREG y = RAM(SP); SP++;					\
	x = y + (RAM(SP) << 8); SP++;					\
} while (0)

#define PUSH(x) do {							\
	--SP; RAM(SP) = (x) >> 8;						\
	--SP; RAM(SP) = x;							\
} while (0)

#define JPC(cond) PC = cond ? GetWORD(PC) : PC+2

#define CALLC(cond) {							\
    if (cond) {								\
	FASTREG adrr = GetWORD(PC);					\
	PUSH(PC+2);							\
	PC = adrr;							\
    }									\
    else								\
	PC += 2;							\
}

/* load Z80 registers into (we hope) host registers */
#define LOAD_STATE()							\
    PC = pc;								\
    AF = af[af_sel];							\
    BC = regs[regs_sel].bc;						\
    DE = regs[regs_sel].de;						\
    HL = regs[regs_sel].hl;						\
EOT
    if ($dfd_inline) {
	print <<'EOT';
    IX = ix;								\
    IY = iy;								\
EOT
    }
    print <<'EOT';
    SP = sp

/* load Z80 registers into (we hope) host registers */
#define DECLARE_STATE()							\
    FASTREG PC = pc;							\
    FASTREG AF = af[af_sel];						\
    FASTREG BC = regs[regs_sel].bc;					\
    FASTREG DE = regs[regs_sel].de;					\
    FASTREG HL = regs[regs_sel].hl;					\
EOT
    if ($dfd_inline) {
	print <<'EOT';
    FASTREG IX = ix;							\
    FASTREG IY = iy;							\
EOT
    }
    print <<'EOT';
    FASTREG SP = sp

/* save Z80 registers back into memory */
#define SAVE_STATE()							\
    pc = PC;								\
    af[af_sel] = AF;							\
    regs[regs_sel].bc = BC;						\
    regs[regs_sel].de = DE;						\
    regs[regs_sel].hl = HL;						\
EOT
    if ($dfd_inline) {
	print <<'EOT';
    ix = IX;								\
    iy = IY;								\
EOT
    }
    print <<'EOT';
    sp = SP

EOT

    if (!$cb_inline) {
	print <<'EOT';
static void
cb_prefix(FASTREG adr)
{
    DECLARE_STATE();
    FASTWORK temp, acu, op, cbits;

EOT
	&cb_switch;
	print <<'EOT';
    SAVE_STATE();
}

EOT
}

    if (!$dfd_inline) {
	print <<'EOT';
static FASTREG
dfd_prefix(FASTREG IXY)
{
    DECLARE_STATE();
    FASTWORK temp, adr, acu, op, sum, cbits;

EOT
	local(@labs) = ($labpcp2, $labcpar, $lablogar,
			$labandar, $labsbcar, $labsubar,
			$labadcar, $labaddar, $labadddd,
			$labdecr, $labincr);
	&dfd_switch("IXY");
	($labpcp2, $labcpar, $lablogar,
	 $labandar, $labsbcar, $labsubar,
	 $labadcar, $labaddar, $labadddd,
	 $labdecr, $labincr) = @labs;
	print <<'EOT';
    SAVE_STATE();
    return(IXY);
}

EOT
}

    if (!$ed_inline) {
	print <<'EOT';
static void
ed_prefix(void)
{
    DECLARE_STATE();
    FASTWORK temp, acu, op, sum, cbits;

EOT
	local(@labs) = ($labpcp2, $labcpar, $lablogar,
			$labandar, $labsbcar, $labsubar,
			$labadcar, $labaddar, $labadddd,
			$labdecr, $labincr);
	&ed_switch;
	($labpcp2, $labcpar, $lablogar,
	 $labandar, $labsbcar, $labsubar,
	 $labadcar, $labaddar, $labadddd,
	 $labdecr, $labincr) = @labs;
	print <<'EOT';
    SAVE_STATE();
}

EOT
}

    print <<'EOT';
FASTWORK
simz80(FASTREG PC)
{
    FASTREG AF = af[af_sel];
    FASTREG BC = regs[regs_sel].bc;
    FASTREG DE = regs[regs_sel].de;
    FASTREG HL = regs[regs_sel].hl;
    FASTREG SP = sp;
EOT
    if ($dfd_inline) {
	print <<'EOT';
    FASTREG IX = ix;
    FASTREG IY = iy;
EOT
    }
    print "    FASTWORK temp, acu, sum, cbits;\n";
    print "    FASTWORK op, adr;\n" if ($cb_inline + $dfd_inline +
				  $ed_inline != 0);

    if ($optab) {
	print "static void *optab[256] = {\n";
	for (0..255) {
	    print "\t" if (($_ & 7) == 0);
	    printf("&&op_%02x,", $_);
	    print "\n" if (($_ & 7) == 7);
	}
	print "};\n";
    }
print <<'EOT';

#ifdef DEBUG
    while (!stopsim) {
#else
    while (1) {
#endif
EOT
    if ($optab) {
	print "    goto *optab[++PC,RAM(PC-1)]; {\n";
    }
    else {
	print "    switch(++PC,RAM(PC-1)) {\n";
    }
    $needbreak = 0;
}

sub postamble {
    print <<'EOT';
    }
    }
/* make registers visible for debugging if interrupted */
    SAVE_STATE();
    return (PC&0xffff)|0x10000;	/* flag non-bios stop */
}
EOT
}
