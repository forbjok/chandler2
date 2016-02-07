module cli.ui.downloadprogressindicator;

import dstatus.status;
import dstatus.progress;
import dstatus.terminal;

class DownloadProgressIndicator : Status {
    private {
        size_t _stepWidth;
        size_t _descriptionWidth;
        size_t _percentTextWidth;
        size_t _progressBarWidth;

        size_t _stepCount;
        size_t _currentStep;
        string _stepDescription;

        string _prevReport;
    }

    this(in int stepCount) {
        auto width = getTerminalWidth();
        _stepCount = stepCount;

        auto progressWidth = (width / 3) - 2;
        _percentTextWidth = 4;
        _progressBarWidth = progressWidth - _percentTextWidth - 1;

        _stepWidth = makeStepCounter(_stepCount, _stepCount).length + 1;
        _descriptionWidth = ((width / 3) * 2) - _stepWidth;
    }

    final void step(in string description) {
        ++_currentStep;
        _stepDescription = description;
    }

    final void progress(in short percent) {
        auto percentText = "%d%%".format(percent).leftJustify(_percentTextWidth);

        auto indicator = text(
            makeStepCounter(_currentStep, _stepCount),
            " ",
            makeProgressBar(_progressBarWidth, percent),
            " ",
            percentText,
            " ",
            makeFixedWidth(_descriptionWidth, _stepDescription));

        // Avoid re-reporting identical text to avoid unnecessary cursor flickering
        if (indicator != _prevReport) {
            report(indicator);
            _prevReport = indicator;
        }
    }
}
