---
layout: post
title: Online ranking accuracy metrics
excerpt: ""
tags: [online, metrics]
modified: 2015-01-05
comments: true
---

  <script type="text/javascript"
	  src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
  </script>

Over the last couple of months I have been doing a lot of work on online ranking problems with a huge class imbalance (say, a 1000 to 1 ratio of negative to positive labels).

When evaluating model quality in this setting I am interested in how well the model separates the positive and the negative class; a perfect model would completely separate the two classes.

In an online problem with balanced classes I could normally use some variant of [progressive accuracy metric](http://www-2.cs.cmu.edu/~jcl/papers/progressive_validation/coltfinal.pdf) to evaluate this:

1. Get a new labelled example.
2. Predict the label.
3. Update the number of correctly classified/incorrectly classified examples seen so far.
4. Update the model with the current example.

If most examples are classified correctly and classes are balanced, I know that I have achieved good class separation.

When the negative class vastly outnumbers the positive class, classification accuracy is a poor measure of separation: if all examples are classified as the majority class accuracy will be high even though there is no class separation.

We could keep track of the average score in both classes, and take any increase in the interclass score distance as an improvement in the model. But this is not scale free and is only mildly informative about the distribution of scores in each class.

### Rank inversion probability

In a ranking setting, what I really want to know is the probability of a rank inversion, where an example from class 0 has a higher score than an example from class 1: $$Pr(S_0 < S_1)$$ when $$S_0$$ and $$S_1$$ are scores of class 0 and 1, respectively.

To do this, we need to an online model of the scores distributions that gives us enough information about $$S_0$$ and $$S_1$$ to compute

$$
Pr(S_0 < S_1) = \int_{y=-\infty}^{\infty}\int_{x=-\infty}^y f_{S_0}(x) f_{S_1}(y) \mathrm{d}x \mathrm{d}y
$$

## Online distributions fitting

I played with one simple and two fun ways of doing this.

### The simple way: running sample

The simplest is to keep a running fixed-size sample of the disributions, evicting old observations as new observations come in. We can then compute the sample estimate of $$P(X < Y)$$ from the data.

This is very easy, and has a nice interpretation ('within the last $$n$$ samples, $$P(X < Y)$$ was $$x$$'). Unfortunately, it may not word very well if the data are not $$\mathrm{iid}$$: if data points that are particularly easy or hard for the model come in bursts (that are large relative to $$n$$), we will get an under- or over-estimate of the inversion probability.

### Fun way #1: online quantile estimation

Estimating quantiles is a fairly natural way of thinking about the problem: if the 70th percentile of the negative score distribution is lower than the 10th percentile of the positive score distribution, we have a faily decent predictive model. 

There seems to be a [rich](http://www.cs.wustl.edu/~jain/papers/ftp/psqr.pdf) [literature](http://jmlr.csail.mit.edu/papers/v11/ben-haim10a.html) about this approach, with a [fair](https://github.com/bigmlcom/histogram) [amount](http://hdrhistogram.github.io/HdrHistogram/) of  [implementations](https://bitbucket.org/scassidy/livestats).

The [Frugal-1U](http://arxiv.org/pdf/1407.1121.pdf) algorithm is particularly simple to implement and has excellent memory characteristics. The basic idea for estimating the median is this:

1. Pick any number $$m$$ as the initial guess for the median.
2. Observe a new data point. If it lies to the left of $$m$$, decrement $$m$$. If it lies to the right, increment it.

It's incredibly simple, but it works. Imagine that you picked an initial value of $$m$$ such that it lies far in the right tail of the distribution. Then the majority of data points will lie to its left, and so it will move left. It will keep moving left, in fact, until the number of points falling on either side is equal -- and we have an estimate of the median. (This is simple to extend to arbitrary quantiles (as per the paper and [this](http://research.neustar.biz/2013/09/16/sketch-of-the-day-frugal-streaming/) blog post)).

### Fun way #2: online Bayesian Gaussian Mixture Model

