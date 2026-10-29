using System;
using System.IO;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Styling;
using Avalonia.Themes.Fluent;

namespace ClipboardPeek;

public sealed class App : Application
{
    // Original, embedded 32-pixel clipboard icon. No external asset or network read.
    private const string TrayIconBase64 =
        "AAABAAEAICAAAAAAIAAAAQAAFgAAAIlQTkcNChoKAAAADUlIRFIAAAAgAAAAIAgGAAAAc3p69AAAAMdJREFUeJxjYBjpgBGfZMSa//+pYcmKEEac9jDR2nJCZmF1GUzDvhoXFPHEGXuIsnB+Bqo+pxaIPmwhgREClFqOTS3MLGwhgeIAalhOqiNwpgF6gaHhAPRERU09RIcAKY4gRS0L0SpJNJhYMDTSwKgDaAmIToT3L5BeGjIwMDAoGuBPuEMnBAj5hFww4CEw4A4YTYSjiXDAHUDVREhONKGEAKzZDGtGUxPgapqT1C+gtuU4HYDsCGoBXN0znIkQX3+OWpYPCgAAxNRPuGoVtpsAAAAASUVORK5CYII=";

    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
        RequestedThemeVariant = ThemeVariant.Dark;
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            OverlayWindow window = new();
            desktop.MainWindow = window;
            desktop.ShutdownMode = ShutdownMode.OnMainWindowClose;

            NativeMenuItem showItem = new("Show Clipboard Peek");
            showItem.Click += (_, _) => window.ShowPreview(activate: true);

            NativeMenuItem exitItem = new("Exit Clipboard Peek");
            exitItem.Click += (_, _) => window.Close();

            NativeMenu menu = new()
            {
                showItem,
                new NativeMenuItemSeparator(),
                exitItem
            };

            using MemoryStream iconData = new(Convert.FromBase64String(TrayIconBase64));
            TrayIcon tray = new()
            {
                Icon = new WindowIcon(iconData),
                ToolTipText = "Clipboard Peek. Waiting for copied text.",
                Menu = menu
            };
            tray.Clicked += (_, _) => window.ShowPreview(activate: true);
            TrayIcon.SetIcons(this, new TrayIcons { tray });
        }

        base.OnFrameworkInitializationCompleted();
    }
}
