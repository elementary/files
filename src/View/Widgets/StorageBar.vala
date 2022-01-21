/*
 * Copyright 2011-2017 Corentin Noël <corentin@elementary.io>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

/**
 * An horizontal bar showing the remaining amount of space.
 *
 * {{../doc/images/StorageBar.png}}
 *
 * ''Example''<<BR>>
 * {{{
 * public class StorageView : Gtk.Grid {
 *     construct {
 *         var file_root = GLib.File.new_for_path ("/");
 *
 *         try {
 *             var info = file_root.query_filesystem_info (GLib.FileAttribute.FILESYSTEM_SIZE, null);
 *
 *             var size = info.get_attribute_uint64 (GLib.FileAttribute.FILESYSTEM_SIZE);
 *
 *             var storage = new Granite.Widgets.StorageBar.with_total_usage (size, size/2);
 *             storage.update_block_size (Granite.Widgets.StorageBar.ItemDescription.AUDIO, size/40);
 *             storage.update_block_size (Granite.Widgets.StorageBar.ItemDescription.VIDEO, size/30);
 *             storage.update_block_size (Granite.Widgets.StorageBar.ItemDescription.APP, size/20);
 *             storage.update_block_size (Granite.Widgets.StorageBar.ItemDescription.PHOTO, size/10);
 *             storage.update_block_size (Granite.Widgets.StorageBar.ItemDescription.FILES, size/5);
 *
 *             add (storage);
 *         } catch (Error e) {
 *             critical (e.message);
 *         }
 *     }
 * }
 * }}}
 */
public class Files.StorageBar : Gtk.Box {
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

    public int inner_margin_sides {
        get {
            return fillblock_box.margin_start;
        }
        set {
            fillblock_box.margin_end = fillblock_box.margin_start = value;
        }
    }

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

    // static construct {
    //     Granite.init ();
    // }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        description_label = new Gtk.Label (null);
        description_label.hexpand = true;
        description_label.margin_top = 6;
        get_style_context ().add_class (Granite.STYLE_CLASS_STORAGEBAR);
        blocks = new GLib.HashTable<int, FillBlock> (null, null);
        fillblock_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        fillblock_box.get_style_context ().add_class (Gtk.STYLE_CLASS_TROUGH);
        fillblock_box.hexpand = true;
        inner_margin_sides = 12;
        legend_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        legend_box.expand = true;
        var legend_center_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        legend_center_box.set_center_widget (legend_box);
        var legend_scrolled = new Gtk.ScrolledWindow (null, null);
        legend_scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
        legend_scrolled.hexpand = true;
        legend_scrolled.add (legend_center_box);
        var grid = new Gtk.Grid ();
        grid.attach (legend_scrolled, 0, 0, 1, 1);
        grid.attach (fillblock_box, 0, 1, 1, 1);
        grid.attach (description_label, 0, 2, 1, 1);
        set_center_widget (grid);

        fillblock_box.size_allocate.connect ((allocation) => {
            // lost_size is here because we use truncation so that it is possible for a full device to have a filed bar.
            double lost_size = 0;
            int current_x = allocation.x;
            for (int i = 0; i < blocks.length; i++) {
                weak FillBlock block = blocks.get (i);
                if (block == null || block.visible == false)
                    continue;

                var new_allocation = Gtk.Allocation ();
                new_allocation.x = current_x;
                new_allocation.y = allocation.y;
                double width = (((double)allocation.width) * (double) block.size / (double) storage) + lost_size;
                lost_size -= GLib.Math.trunc (lost_size);
                new_allocation.width = (int) GLib.Math.trunc (width);
                new_allocation.height = allocation.height;
                block.size_allocate_with_baseline (new_allocation, block.get_allocated_baseline ());

                lost_size = width - new_allocation.width;
                current_x += new_allocation.width;
            }
        });

        create_default_blocks ();
    }

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
            fillblock_box.add (fill_block);
            legend_box.add (fill_block.legend_item);
            blocks.set (index, fill_block);
            index++;
        });

        free_space = new FillBlock (ItemDescription.FILES, storage);
        used_space = new FillBlock (ItemDescription.FILES, total_usage);
        free_space.get_style_context ().add_class ("empty-block");
        free_space.get_style_context ().remove_class ("files");
        used_space.get_style_context ().remove_class ("files");
        blocks.set (index++, used_space);
        blocks.set (index++, free_space);
        fillblock_box.add (used_space);
        fillblock_box.add (free_space);

        update_size_description ();
    }

    private void update_size_description () {
        uint64 user_size = 0;
        foreach (weak FillBlock block in blocks.get_values ()) {
            if (block.visible == false || block == free_space || block == used_space)
                continue;
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

    internal class FillBlock : FillRound {
        private uint64 _size = 0;
        public uint64 size {
            get {
                return _size;
            }
            set {
                _size = value;
                if (_size == 0) {
                    no_show_all = true;
                    visible = false;
                    legend_item.no_show_all = true;
                    legend_item.visible = false;
                } else {
                    no_show_all = false;
                    visible = true;
                    legend_item.no_show_all = false;
                    legend_item.visible = true;
                    size_label.label = GLib.format_size (_size);
                    queue_resize ();
                }
            }
        }

        public ItemDescription description { public get; construct set; }
        public Gtk.Grid legend_item { public get; private set; }
        private Gtk.Label name_label;
        private Gtk.Label size_label;
        private FillRound legend_fill;

        internal FillBlock (ItemDescription description, uint64 size) {
            Object (size: size, description: description);
            var clas = ItemDescription.get_class (description);
            if (clas != null) {
                get_style_context ().add_class (clas);
                legend_fill.get_style_context ().add_class (clas);
            }

            name_label.label = "<b>%s</b>".printf (GLib.Markup.escape_text (ItemDescription.get_name (description)));
        }

        construct {
            show_all ();
            legend_item = new Gtk.Grid ();
            legend_item.column_spacing = 6;
            name_label = new Gtk.Label (null);
            name_label.halign = Gtk.Align.START;
            name_label.use_markup = true;
            size_label = new Gtk.Label (null);
            size_label.halign = Gtk.Align.START;
            legend_fill = new FillRound ();
            legend_fill.get_style_context ().add_class ("legend");
            var legend_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            legend_box.set_center_widget (legend_fill);
            legend_item.attach (legend_box, 0, 0, 1, 2);
            legend_item.attach (name_label, 1, 0, 1, 1);
            legend_item.attach (size_label, 1, 1, 1, 1);
        }
    }

    internal class FillRound : Gtk.Widget {
        internal FillRound () {

        }

        construct {
            set_has_window (false);
            var style_context = get_style_context ();
            style_context.add_class ("fill-block");
            expand = true;
        }

        public override bool draw (Cairo.Context cr) {
            var width = get_allocated_width ();
            var height = get_allocated_height ();
            var context = get_style_context ();
            context.render_background (cr, 0, 0, width, height);
            context.render_frame (cr, 0, 0, width, height);
            return true;
        }

        public override void get_preferred_width (out int minimum_width, out int natural_width) {
            base.get_preferred_width (out minimum_width, out natural_width);
            var context = get_style_context ();
            var padding = context.get_padding (get_state_flags ());
            minimum_width = int.max (padding.left + padding.right, minimum_width);
            minimum_width = int.max (1, minimum_width);
            natural_width = int.max (minimum_width, natural_width);
        }

        public override void get_preferred_height (out int minimum_height, out int natural_height) {
            base.get_preferred_height (out minimum_height, out natural_height);
            var context = get_style_context ();
            var padding = context.get_padding (get_state_flags ());
            minimum_height = int.max (padding.top + padding.bottom, minimum_height);
            minimum_height = int.max (1, minimum_height);
            natural_height = int.max (minimum_height, natural_height);
        }
    }
}
