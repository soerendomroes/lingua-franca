/*
 * Copyright (c) 2021, TU Dresden.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package org.lflang.tests.util;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.lflang.util.StringUtil.camelToSnakeCase;
import static org.lflang.util.StringUtil.removeQuotes;

import org.junit.jupiter.api.Test;

public class StringUtilTest {

    @Test
    public void testRemoveQuotes() {
        assertEquals("abc", removeQuotes("\"abc\""));
        assertEquals("a", removeQuotes("'a'"));
        assertEquals("'a", removeQuotes("'a"));
        assertEquals("a\"", removeQuotes("a\""));
        assertEquals("\"", removeQuotes("\""));
        assertEquals("'", removeQuotes("'"));
        assertEquals("", removeQuotes(""));
        assertNull(removeQuotes(null));
    }

    @Test
    public void testCamelToSnakeCase() {
        assertEquals("some_string", camelToSnakeCase("someString"));
        assertEquals("abc_str", camelToSnakeCase("AbcStr"));
        assertEquals("ast", camelToSnakeCase("AST"));
        assertEquals("ast_builder", camelToSnakeCase("ASTBuilder"));
        assertEquals("something_with_a_preamble", camelToSnakeCase("SomethingWithAPreamble"));
    }
}
