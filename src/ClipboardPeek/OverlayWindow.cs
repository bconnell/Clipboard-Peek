using System;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using ClipboardPeek.Core;

namespace ClipboardPeek;

public sealed class OverlayWindow : Window
{
    private readonly PreviewState _preview = new();
    private readonly DispatcherTimer _clipboardTimer;
    private readonly Border _surface;
    private readonly TextBox _textBox;
    private readonly TextBlock _opacityLabel;
    private readonly TextBlock _status;
    private readonly Button _freezeButton;
    private readonly Button _maskButton;
    private readonly Button _pinButton;

    private bool _readingClipboard;
    private bool _closed;

    public OverlayWindow()
    {
        Title = "Clipboard Peek";
        Width = 440;
        Height = 250;
        MinWidth = 400;
        MinHeight = 170;
        CanResize = true;
        Topmost = true;
        ShowInTaskbar = true;
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
        };

        Button closeButton = MakeButton("×");
        closeButton.Click += (_, _) => Close();

        Border resizeGrip = new()
        {
            Background = Brushes.Transparent,
            Padding = new Thickness(7, 3),
            Child = new TextBlock
            {
                Text = "↘",
                Foreground = Brushes.White,
                FontSize = 13
            }
        };
        ToolTip.SetTip(resizeGrip, "Drag to resize");
        resizeGrip.PointerPressed += (_, eventArgs) =>
        {
            if (eventArgs.GetCurrentPoint(this).Properties.IsLeftButtonPressed)
            {
                BeginResizeDrag(WindowEdge.BottomRight, eventArgs);
            }
        };

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
                clearButton,
                resizeGrip
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
        footer.Children.Add(rightFooter);

        _surface = new Border
        {
            Margin = new Thickness(3),
            Padding = new Thickness(10),
            CornerRadius = new CornerRadius(12),
            BorderThickness = new Thickness(1),
            BorderBrush = new SolidColorBrush(Color.FromArgb(95, 122, 166, 226)),
            Child = panelContents
        };

        Content = _surface;
        ApplySurfaceOpacity(opacitySlider.Value);
        RenderState();

        _clipboardTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(700)
        };
        _clipboardTimer.Tick += OnClipboardTick;
        Opened += (_, _) =>
        {
            _clipboardTimer.Start();
            OnClipboardTick(this, EventArgs.Empty);
        };
        Closed += (_, _) =>
        {
            _closed = true;
            _clipboardTimer.Stop();
            _preview.DisposeContent();
        };
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
        if (Clipboard is null)
        {
            return;
        }

        string? copiedText = await Clipboard.TryGetTextAsync();
        if (_closed || _preview.IsFrozen)
        {
            return;
        }

        if (_preview.Observe(copiedText))
        {
            RenderState();
        }
    }
}
