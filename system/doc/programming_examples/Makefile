#
# %CopyrightBegin%
# 
# Copyright Ericsson AB 2003-2009. All Rights Reserved.
# 
# The contents of this file are subject to the Erlang Public License,
# Version 1.1, (the "License"); you may not use this file except in
# compliance with the License. You should have received a copy of the
# Erlang Public License along with this software. If not, it can be
# retrieved online at http://www.erlang.org/.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# %CopyrightEnd%
#
#
include $(ERL_TOP)/make/target.mk
include $(ERL_TOP)/make/$(TARGET)/otp.mk

# ----------------------------------------------------
# Application version
# ----------------------------------------------------
include $(ERL_TOP)/erts/vsn.mk
#VSN=$(SYSTEM_VSN)

APPLICATION=otp-system-documentation
# ----------------------------------------------------
# Release directory specification
# ----------------------------------------------------
RELSYSDIR = $(RELEASE_PATH)/doc/programming_examples

# ----------------------------------------------------
# Target Specs
# ----------------------------------------------------
XML_PART_FILES = part.xml

include xmlfiles.mk

XML_CHAPTER_FILES=$(PROG_EX_CHAPTER_FILES)

TOPDOCDIR=..

BOOK_FILES = book.xml

GIF_FILES = 

PS_FILES = 

XML_FILES = \
	$(BOOK_FILES) $(XML_CHAPTER_FILES) \
	$(XML_PART_FILES) 
# ----------------------------------------------------

HTML_FILES = \
	$(XML_PART_FILES:%.xml=%.html)

HTMLDIR = ../html/programming_examples

HTML_UG_FILE = $(HTMLDIR)/users_guide.html

# ----------------------------------------------------
# FLAGS 
# ----------------------------------------------------
XML_FLAGS += 
DVIPS_FLAGS += 

# ----------------------------------------------------
# Targets
# ----------------------------------------------------
docs: html
local_docs: PDFDIR=../../pdf

html: $(GIF_FILES) $(HTML_UG_FILE)

debug opt: 

clean clean_docs:
	rm -rf $(HTMLDIR)
	rm -f $(TOP_PDF_FILE) $(TOP_PDF_FILE:%.pdf=%.fo)
	rm -f errs core *~ 

# ----------------------------------------------------
# Release Target
# ---------------------------------------------------- 
include $(ERL_TOP)/make/otp_release_targets.mk

release_docs_spec: docs
	$(INSTALL_DIR) $(RELSYSDIR)
	$(INSTALL_DATA) $(GIF_FILES) $(HTMLDIR)/*.html \
		$(RELSYSDIR)

release_spec:



