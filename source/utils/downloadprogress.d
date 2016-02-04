import dstatus.status;
import dstatus.progress;
import dstatus.terminal;

class DownloadProgressIndicator : Status {
    private {
        int _stepWidth;
        int _descriptionWidth;
        int _percentTextWidth;
        int _progressBarWidth;

        int _stepCount;
        int _currentStep;
        string _stepDescription;
    }

    this(in int stepCount) {
        auto width = getTerminalWidth();
        _stepCount = stepCount;

        _stepWidth = makeStepCounter(_stepCount, _stepCount).length + 1;
        _descriptionWidth = (width / 2) - _stepWidth;

        auto progressWidth = (width / 2) - 2;
        _percentTextWidth = 4;
        _progressBarWidth = progressWidth - _percentTextWidth - 1;
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

        report(indicator);
    }
}
