/*-
 * Copyright 2026 elementary, Inc. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
 */

 public class Files.FileFilter : Object {
    enum PatternType {
        GLOB,
        MIME
    }

    struct Pattern {
        PatternType type;
        string text;
    }

    public string name { get; set; }
    private List<Pattern?> patterns;
    // Create from filechooser portal variant type "sa(us)"
    public FileFilter.from_gvariant (Variant filter_variant) {
        VariantIter iter;
        string _name;
        PatternType _type;
        string _text;


        filter_variant.@get ("sa(us)", out _name, out iter);
        name = _name;

        while (iter.next ("(us)", out _type, out _text)) {
            patterns.append (Pattern () {type = _type, text = _text});
        }
    }

    construct {
        patterns = new List<Pattern?> ();
    }

    public void add_mime_type (string type) {
        patterns.append (Pattern () { type = PatternType.MIME, text = type });
    }

    public void add_pattern (string pattern) {
        patterns.append (Pattern () { type = PatternType.GLOB, text = pattern });
    }

    public Variant to_gvariant () {
        var vb = new VariantBuilder (new VariantType ("sa(us)"));
        vb.add (name);
        vb.open (new VariantType ("a(us)"));
        patterns.foreach ((pattern) => {
            vb.add ("(us)", pattern.type, pattern.text);
        });
        vb.close ();

        return vb.end ();
    }

    //TODO decide whether should accept or reject by default
    public bool filter (Files.File file) {
        var matcher = Posix.Glob ();
        var res = false;
        foreach (Pattern p in patterns) {
            if (p.type == MIME) {
                if (ContentType.is_mime_type (file.get_ftype (), p.text)) {
                    res = true;
                    break;
                }
            } else { // GLOB - only apply to display name for now
                try {
                    if (matcher.glob (p.text) == 0) {
                        res = true;
                        break;
                    }
                } catch (Error e) {
                    return true;  // Maybe false?
                }
            }
        }

        warning ("filter %s", res.to_string ());
        return res;
    }
 }
