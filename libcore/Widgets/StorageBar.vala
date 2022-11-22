/*
 * Copyright 2011-2017 Corentin Noël <corentin@elementary.io>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

//Moved here from Granite
public class Files.StorageBar : Gtk.Widget {
    static construct {
        set_layout_manager_type (typeof (Gtk.BoxLayout));
    }

    // private Gtk.CenterBox center_box;
    public enum ItemDescription {
        OTHER,
        AUDIO,
        VIDEO,
        PHOTO,
        APP,
        FILES = OTHER;

        public static string? get_class (ItemDescription description) {
            switch (description) {
                case ItemDescription.FILES:
                    return "files";
                case ItemDescription.AUDIO:
                    return "audio";
                case ItemDescription.VIDEO:
                    return "video";
                case ItemDescription.PHOTO:
                    return "photo";
                case ItemDescription.APP:
                    return "app";
                default:
                    return null;
            }
        }

        public static string get_name (ItemDescription description) {
            switch (description) {
                case ItemDescription.AUDIO:
                    return _("Audio");
                case ItemDescription.VIDEO:
                    /// TRANSLATORS: Refers to videos the mime type. Not Videos the app.
                    return _("Videos");
                case ItemDescription.PHOTO:
                    /// TRANSLATORS: Refers to photos the mime type. Not Photos the app.
                    return _("Photos");
                case ItemDescription.APP:
                    return _("Apps");
                case ItemDescription.FILES:
                    /// TRANSLATORS: Refers to files the mime type. Not Files the app.
                    return _("Files");
                default:
                    return _("Other");
            }
        }
    }

    private uint64 _storage = 0;
    public uint64 storage {
        get {
            return _storage;
        }

        set {
            _storage = value;
            update_size_description ();
        }
    }

    private uint64 _total_usage = 0;

    public uint64 total_usage {
        get {
            return _total_usage;
        }

        set {
            _total_usage = uint64.min (value, storage);
            update_size_description ();
        }
    }

    // public int inner_margin_sides {
    //     get {
    //         return fillblock_box.margin_start;
    //     }
    //     set {
    //         fillblock_box.margin_end = fillblock_box.margin_start = value;
    //     }
    // }

    private Gtk.Label description_label;
    private GLib.HashTable<int, FillBlock> blocks;
    private int index = 0;
    private Gtk.Box fillblock_box;
    private Gtk.Box legend_box;
    private FillBlock free_space;
    private FillBlock used_space;

    /**
     * Creates a new StorageBar widget with the given amount of space.
     *
     * @param storage the total amount of space.
     */
    public StorageBar (uint64 storage) {
        Object (storage: storage);
    }

    /**
     * Creates a new StorageBar widget with the given amount of space.an a larger total usage block
     *
     * @param storage the total amount of space.
     * @param usage the amount of space used.
     */
    public StorageBar.with_total_usage (uint64 storage, uint64 total_usage) {
        Object (storage: storage, total_usage: total_usage);
    }

    construct {
        set_layout_manager (new Gtk.BoxLayout (Gtk.Orientation.VERTICAL));
        // center_box = new Gtk.CenterBox ();
        // center_box.set_parent (this);
        // orientation = Gtk.Orientation.VERTICAL;
        description_label = new Gtk.Label ("DESCRIPTION LABEL") {
            hexpand = true,
            margin_top = 6
        };
        // add_css_class ("storage-bar");
        blocks = new GLib.HashTable<int, FillBlock> (null, null);
        fillblock_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            hexpand = true,
            margin_start = 12,
            margin_end = 12
        };
        fillblock_box.add_css_class ("trough");
        // fillblock_box.hexpand = true;
        // inner_margin_sides = 12;
        legend_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        // var legend_center_box = new Gtk.CenterBox ();
        // legend_center_box.set_center_widget (legend_box);
        var legend_scrolled = new Gtk.ScrolledWindow () {
            vscrollbar_policy = Gtk.PolicyType.ALWAYS,
            hscrollbar_policy = Gtk.PolicyType.ALWAYS,
            hexpand = true,
            vexpand = true
        };
        legend_scrolled.set_child (legend_box);
        // var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        create_default_blocks ();

        legend_scrolled.set_parent (this);
        fillblock_box.set_parent (this);
        description_label.set_parent (this);
        // box.set_parent (this);
        // center_box.set_center_widget (box);
        // center_box.set_start_widget (new Gtk.Label ("START"));
        // center_box.set_end_widget (new Gtk.Label ("END"));

    }

    //TODO Work out what is needed in Gtk4
    // public override void size_allocate (int width, int height, int baseline) {
    //     // lost_size is here because we use truncation so that it is possible for a full device to have a filled bar.
    //     double lost_size = 0;
    //     for (int i = 0; i < blocks.length; i++) {
    //         weak FillBlock block = blocks.get (i);
    //         if (block == null || block.visible == false)
    //             continue;

    //         new_allocation.x = current_x;
    //         new_allocation.y = allocation.y;
    //         double width = (((double)allocation.width) * (double) block.size / (double) storage) + lost_size;
    //         lost_size -= GLib.Math.trunc (lost_size);
    //         new_allocation.width = (int) GLib.Math.trunc (width);
    //         new_allocation.height = allocation.height;
    //         block.size_allocate_with_baseline (new_allocation, block.get_allocated_baseline ());

    //         lost_size = width - new_allocation.width;
    //         current_x += new_allocation.width;
    //     }
    // }

    private void create_default_blocks () {
        var seq = new Sequence<ItemDescription> ();
        seq.append (ItemDescription.FILES);
        seq.append (ItemDescription.AUDIO);
        seq.append (ItemDescription.VIDEO);
        seq.append (ItemDescription.PHOTO);
        seq.append (ItemDescription.APP);
        seq.sort ((a, b) => {
            if (a == ItemDescription.FILES)
                return 1;
            if (b == ItemDescription.FILES)
                return -1;

            return ItemDescription.get_name (a).collate (ItemDescription.get_name (b));
        });

        seq.foreach ((description) => {
            var fill_block = new FillBlock (description, 0);
            fillblock_box.append (fill_block.legend_fill);
            legend_box.append (fill_block.legend_item);
            blocks.set (index, fill_block);
            index++;
        });

        free_space = new FillBlock (ItemDescription.FILES, storage);
        used_space = new FillBlock (ItemDescription.FILES, total_usage);
        free_space.legend_fill.add_css_class ("empty-block");
        free_space.legend_fill.remove_css_class ("files");
        used_space.legend_fill.remove_css_class ("files");
        blocks.set (index++, used_space);
        blocks.set (index++, free_space);
        fillblock_box.append (used_space.legend_fill);
        fillblock_box.append (free_space.legend_fill);

        update_size_description ();
    }

    private void update_size_description () {
        uint64 user_size = 0;
        foreach (weak FillBlock block in blocks.get_values ()) {
            if (block == free_space || block == used_space) {
                continue;
            }

            user_size += block.size;
        }

        uint64 free;
        if (user_size > total_usage) {
            free = storage - user_size;
            used_space.size = 0;
        } else {
            free = storage - total_usage;
            used_space.size = total_usage - user_size;
        }

        free_space.size = free;
        description_label.label = _("%s free out of %s").printf (GLib.format_size (free), GLib.format_size (storage));
    }

    /**
     * Update the specified block with a given amount of space.
     *
     * @param description the category to update.
     * @param size the size of the category or 0 to hide.
     */
    public void update_block_size (ItemDescription description, uint64 size) {
        foreach (weak FillBlock block in blocks.get_values ()) {
            if (block.description == description) {
                block.size = size;
                update_size_description ();
                return;
            }
        }
    }

    internal class FillBlock : Object {
        private uint64 _size = 0;
        public uint64 size {
            get {
                return _size;
            }
            set {
                _size = value;
                if (_size == 0) {
                } else {
                    size_label.label = GLib.format_size (_size);
                }
            }
        }

        public ItemDescription description { public get; construct set; }
        public Gtk.Grid legend_item { public get; private set; }
        private Gtk.Label name_label;
        private Gtk.Label size_label;
        public Gtk.Label legend_fill { public get; private set; }

        internal FillBlock (ItemDescription description, uint64 size) {
            Object (size: size, description: description);
            var clas = ItemDescription.get_class (description);
            if (clas != null) {
                legend_fill.add_css_class (clas);
            }

            name_label.label = "<b>%s</b>".printf (GLib.Markup.escape_text (ItemDescription.get_name (description)));
        }

        construct {
            legend_item = new Gtk.Grid () {
                column_spacing = 6
            };

            name_label = new Gtk.Label (null) {
                halign = Gtk.Align.START,
                use_markup = true,
            };
            size_label = new Gtk.Label ("SIZE") {
                halign = Gtk.Align.START
            };

            legend_fill = new Gtk.Label ("FILL");
            legend_fill.add_css_class ("legend");

            // legend_item.attach (legend_fill, 0, 0, 2, 1);
            legend_item.attach (name_label, 0, 0, 1, 1);
            legend_item.attach (size_label, 0, 1, 1, 1);
        }
    }

    // internal class FillRound : Gtk.Widget {
    //     // internal FillRound () {

    //     // }

    //     construct {
    //         // set_has_window (false);
    //         add_css_class ("fill-block");
    //     }

    //     public override void snapshot (Gtk.Snapshot ss) {
    //     // public override bool draw (Cairo.Context cr) {
    //         var width = get_allocated_width ();
    //         var height = get_allocated_height ();
    //         var context = get_style_context ();
    //         ss.render_background (context, 0, 0, width, height);
    //         ss.render_frame (context, 0, 0, width, height);
    //     }

        //TODO Implement get_preferred_size if required
        // public override void get_preferred_size (out Gtk.Requisition min_size, out Gtk.Requisition nat_size) {

        // }
        // public override void get_preferred_width (out int minimum_width, out int natural_width) {
        //     base.get_preferred_width (out minimum_width, out natural_width);
        //     var context = get_style_context ();
        //     var padding = context.get_padding (get_state_flags ());
        //     minimum_width = int.max (padding.left + padding.right, minimum_width);
        //     minimum_width = int.max (1, minimum_width);
        //     natural_width = int.max (minimum_width, natural_width);
        // }

        // public override void get_preferred_height (out int minimum_height, out int natural_height) {
        //     base.get_preferred_height (out minimum_height, out natural_height);
        //     var context = get_style_context ();
        //     var padding = context.get_padding (get_state_flags ());
        //     minimum_height = int.max (padding.top + padding.bottom, minimum_height);
        //     minimum_height = int.max (1, minimum_height);
        //     natural_height = int.max (minimum_height, natural_height);
        // }
    // }
}
