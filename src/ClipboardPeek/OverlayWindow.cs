using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Input.Platform;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ClipboardPeek.Core;

namespace ClipboardPeek;

public sealed class OverlayWindow : Window
{
    private readonly PreviewState _preview = new();
    private readonly ClipboardChangeGate _changeGate = new();
    private readonly DispatcherTimer _clipboardTimer;
    private readonly Border _surface;
    private readonly TextBox _textBox;
    private readonly TextBlock _opacityLabel;
    private readonly TextBlock _status;
    private readonly Button _freezeButton;
    private readonly Button _maskButton;
    private readonly Button _pinButton;

    private bool _readingClipboard;
    private bool _openedOnce;
    private bool _closed;
    private IClipboard? _monitorClipboard;

    public OverlayWindow()
    {
        ulong? startupSequence = WindowsClipboardSequence.Read();
        if (startupSequence.HasValue)
        {
            _changeGate.PrimeSequence(startupSequence.Value);
        }

        Title = "Clipboard Peek";
        Width = 440;
        Height = 250;
        MinWidth = 400;
        MinHeight = 170;
        CanResize = true;
        Topmost = true;
        // The window is initially invisible; a tray menu makes the process recoverable.
        ShowInTaskbar = false;
        ShowActivated = false;
        Opacity = 0;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        WindowDecorations = WindowDecorations.None;
        TransparencyLevelHint = [WindowTransparencyLevel.Transparent];
        Background = Brushes.Transparent;

        _opacityLabel = new TextBlock
        {
            Foreground = Brushes.White,
            FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center
        };

        _status = new TextBlock
        {
            Foreground = Brushes.LightGray,
            FontSize = 10,
            Text = "Local preview. No history saved.",
            VerticalAlignment = VerticalAlignment.Center
        };

        _textBox = new TextBox
        {
            Text = _preview.DisplayText,
            AcceptsReturn = true,
            IsReadOnly = true,
            TextWrapping = TextWrapping.Wrap,
            FontSize = 14,
            FontFamily = FontFamily.Default,
            Background = Brushes.Transparent,
            Foreground = Brushes.White,
            BorderThickness = new Thickness(0),
            Padding = new Thickness(4)
        };

        _freezeButton = MakeButton("Freeze");
        _freezeButton.Click += (_, _) =>
        {
            _preview.SetFrozen(!_preview.IsFrozen);
            RenderState();
        };

        _maskButton = MakeButton("Hide");
        _maskButton.Click += (_, _) =>
        {
            _preview.SetMasked(!_preview.IsMasked);
            RenderState();
        };

        _pinButton = MakeButton("Unpin");
        _pinButton.Click += (_, _) =>
        {
            Topmost = !Topmost;
            RenderState();
        };

        Button clearButton = MakeButton("Clear");
        clearButton.Click += (_, _) =>
        {
            _preview.Clear();
            RenderState();
            DismissPreview();
        };

        Button closeButton = MakeButton("×");
        ToolTip.SetTip(closeButton, "Dismiss preview. Clipboard Peek remains in the tray.");
        closeButton.Click += (_, _) => DismissPreview();

        Slider opacitySlider = new()
        {
            Minimum = 10,
            Maximum = 100,
            Value = 30,
            Width = 108,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(8, 0)
        };
        opacitySlider.PropertyChanged += (_, eventArgs) =>
        {
            if (eventArgs.Property == RangeBase.ValueProperty)
            {
                ApplySurfaceOpacity(opacitySlider.Value);
            }
        };

        StackPanel titlePanel = new()
        {
            Orientation = Orientation.Horizontal,
            Spacing = 7,
            Children =
            {
                new TextBlock
                {
                    Text = "▣",
                    FontSize = 16,
                    Foreground = Brushes.LightSkyBlue,
                    VerticalAlignment = VerticalAlignment.Center
                },
                new TextBlock
                {
                    Text = "Clipboard Peek",
                    FontWeight = FontWeight.SemiBold,
                    FontSize = 13,
                    Foreground = Brushes.White,
                    VerticalAlignment = VerticalAlignment.Center
                }
            }
        };

        Border titleDragRegion = new()
        {
            Background = Brushes.Transparent,
            Child = titlePanel,
            VerticalAlignment = VerticalAlignment.Stretch
        };
        titleDragRegion.PointerPressed += (_, eventArgs) =>
        {
            if (eventArgs.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
            {
                BeginMoveDrag(eventArgs);
            }
        };

        StackPanel headerActions = new()
        {
            Orientation = Orientation.Horizontal,
            Spacing = 4,
            Children = { _pinButton, _freezeButton, _maskButton, closeButton }
        };

        Grid header = new() { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        header.Children.Add(titleDragRegion);
        Grid.SetColumn(headerActions, 1);
        header.Children.Add(headerActions);

        StackPanel rightFooter = new()
        {
            Orientation = Orientation.Horizontal,
            Spacing = 2,
            VerticalAlignment = VerticalAlignment.Center,
            Children =
            {
                _opacityLabel,
                opacitySlider,
                clearButton
            }
        };

        Grid footer = new() { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        footer.Children.Add(_status);
        Grid.SetColumn(rightFooter, 1);
        footer.Children.Add(rightFooter);

        Grid panelContents = new() { RowDefinitions = new RowDefinitions("Auto,*,Auto"), RowSpacing = 8 };
        panelContents.Children.Add(header);
        Grid.SetRow(_textBox, 1);
        panelContents.Children.Add(_textBox);
        Grid.SetRow(footer, 2);
        panelContents.Children.Add(footer);

        _surface = new Border
        {
            Margin = new Thickness(3),
            Padding = new Thickness(10),
            CornerRadius = new CornerRadius(12),
            BorderThickness = new Thickness(1),
            BorderBrush = new SolidColorBrush(Color.FromArgb(95, 122, 166, 226)),
            Child = panelContents
        };

        // The 3 by 3 overlay reserves 10 physical layout units for every edge and
        // corner. The surface is drawn underneath, with each resize zone on top.
        Grid resizeOverlay = new()
        {
            RowDefinitions = new RowDefinitions("10,*,10"),
            ColumnDefinitions = new ColumnDefinitions("10,*,10")
        };
        Grid.SetRowSpan(_surface, 3);
        Grid.SetColumnSpan(_surface, 3);
        resizeOverlay.Children.Add(_surface);
        AddResizeZone(resizeOverlay, 0, 0, WindowEdge.NorthWest, StandardCursorType.TopLeftCorner);
        AddResizeZone(resizeOverlay, 0, 1, WindowEdge.North, StandardCursorType.SizeNorthSouth);
        AddResizeZone(resizeOverlay, 0, 2, WindowEdge.NorthEast, StandardCursorType.TopRightCorner);
        AddResizeZone(resizeOverlay, 1, 0, WindowEdge.West, StandardCursorType.SizeWestEast);
        AddResizeZone(resizeOverlay, 1, 2, WindowEdge.East, StandardCursorType.SizeWestEast);
        AddResizeZone(resizeOverlay, 2, 0, WindowEdge.SouthWest, StandardCursorType.BottomLeftCorner);
        AddResizeZone(resizeOverlay, 2, 1, WindowEdge.South, StandardCursorType.SizeNorthSouth);
        AddResizeZone(resizeOverlay, 2, 2, WindowEdge.SouthEast, StandardCursorType.BottomRightCorner);
        Content = resizeOverlay;
        ApplySurfaceOpacity(opacitySlider.Value);
        RenderState();

        _clipboardTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(700)
        };
        _clipboardTimer.Tick += OnClipboardTick;
        Opened += (_, _) =>
        {
            if (_openedOnce)
            {
                return;
            }

            _openedOnce = true;
            // Create the native window without showing even a startup frame.
            _monitorClipboard = Clipboard;
            Hide();
            Opacity = 1;
            _clipboardTimer.Start();
            OnClipboardTick(this, EventArgs.Empty);
        };
        Closed += (_, _) =>
        {
            _closed = true;
            _clipboardTimer.Stop();
            _preview.DisposeContent();
            _changeGate.Reset();
        };
    }

    private void AddResizeZone(Grid root, int row, int column, WindowEdge edge, StandardCursorType cursor)
    {
        Border target = new()
        {
            Background = Brushes.Transparent,
            Cursor = new Cursor(cursor)
        };
        Grid.SetRow(target, row);
        Grid.SetColumn(target, column);
        target.PointerPressed += (_, args) =>
        {
            if (args.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
            {
                BeginResizeDrag(edge, args);
                args.Handled = true;
            }
        };
        root.Children.Add(target);
    }

    public void ShowPreview(bool activate = false)
    {
        if (_closed)
        {
            return;
        }

        ShowInTaskbar = true;
        if (!IsVisible)
        {
            Show();
        }

        if (activate)
        {
            Activate();
        }
    }

    private void DismissPreview()
    {
        if (!_closed)
        {
            Hide();
            ShowInTaskbar = false;
        }
    }

    private static Button MakeButton(string label) => new()
    {
        Content = label,
        FontSize = 11,
        MinWidth = 28,
        Padding = new Thickness(7, 3),
        Background = new SolidColorBrush(Color.FromArgb(65, 77, 112, 160)),
        Foreground = Brushes.White,
        VerticalAlignment = VerticalAlignment.Center
    };

    private void ApplySurfaceOpacity(double percent)
    {
        byte alpha = (byte)Math.Round(Math.Clamp(percent, 10, 100) * 255 / 100);
        _surface.Background = new SolidColorBrush(Color.FromArgb(alpha, 11, 21, 36));
        _opacityLabel.Text = $"Tint {Math.Round(percent):0}%";
    }

    private void RenderState()
    {
        _textBox.Text = _preview.DisplayText;
        _freezeButton.Content = _preview.IsFrozen ? "Resume" : "Freeze";
        _maskButton.Content = _preview.IsMasked ? "Show" : "Hide";
        _pinButton.Content = Topmost ? "Unpin" : "Pin";
    }

    private async void OnClipboardTick(object? sender, EventArgs eventArgs)
    {
        if (_readingClipboard || _closed || _preview.IsFrozen)
        {
            return;
        }

        _readingClipboard = true;
        try
        {
            await ReadClipboardAsync();
            if (!_closed)
            {
                _status.Text = "Local preview. No history saved.";
            }
        }
        catch (Exception)
        {
            // Do not log clipboard data, including exceptions with private content.
            if (!_closed)
            {
                _status.Text = "Clipboard currently unavailable.";
            }
        }
        finally
        {
            _readingClipboard = false;
        }
    }

    private async Task ReadClipboardAsync()
    {
        IClipboard? clipboard = _monitorClipboard ?? Clipboard;
        if (clipboard is null)
        {
            return;
        }

        ulong? sequenceBefore = WindowsClipboardSequence.Read();
        if (_changeGate.HasUnchangedNativeSequence(sequenceBefore))
        {
            // On Windows an unchanged clipboard token avoids fetching large content.
            return;
        }

        string? copiedText = await clipboard.TryGetTextAsync();
        ulong? sequenceAfter = WindowsClipboardSequence.Read();
        if (_closed || _preview.IsFrozen)
        {
            return;
        }

        // Do not take a baseline from a clipboard that changed during the read.
        if (sequenceBefore.HasValue && sequenceAfter.HasValue &&
            sequenceBefore.Value != sequenceAfter.Value)
        {
            return;
        }

        if (_changeGate.Observe(copiedText, sequenceAfter))
        {
            _preview.Observe(copiedText, force: true);
            RenderState();
            ShowPreview();
        }
    }
}

internal static partial class WindowsClipboardSequence
{
    [LibraryImport("user32.dll", EntryPoint = "GetClipboardSequenceNumber")]
    private static partial uint GetClipboardSequenceNumber();

    internal static ulong? Read()
    {
        if (!OperatingSystem.IsWindows())
        {
            return null;
        }

        uint sequence = GetClipboardSequenceNumber();
        return sequence == 0 ? null : sequence;
    }
}
