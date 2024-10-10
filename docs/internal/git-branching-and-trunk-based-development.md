# Git Branching and Trunk-Based Development
[Trunk-Based Development](https://trunkbaseddevelopment.com/) is a git branching strategy where the whole team integrates work into a "trunk" branch—`main` in our case. Changes are merged there frequently from short-lived feature branches. There are no other long-lived branches like a `develop` branch.

By merging all code changes into the trunk frequently you get several benefits.
- When a bug gets fixed, everyone's development code is improved.
- Frequent small check-ins reduce the likelihood of merge conflicts, and reduces their size and complexity when they do happen.

To maintain stability, we must not merge code to the trunk that leaves it "broken". In other words, builds must always succeed and tests must always pass on every commit/pull request before it is merged into the trunk. Automated build pipelines on pull requests can help maintain this. But it is also helpful to run the build and test suite locally before pull request submission.
## Branches
- Do day-to-day work in feature branches.
- To start a new branch, ensure you have pulled the latest `main` from the origin, and create your feature branch from it.
	- Do not reuse old branches. You can reuse the name if you think it makes sense but the new branch should always start from a commit on `main`, not a commit from another branch.
- If you are working on something associated with a JIRA ticket, it can be useful to include the ticket in the branch name in a format like `<ticket>-<description>`. For example: `PROJ-1-git-model-doc`.
## Pull Requests and Code Review
Trunk-based development can support a high commit velocity, where every developer is making at least one commit to the trunk every day. I don't expect our team to achieve this velocity—in part because it isn't necessary for us—but we can adopt work practices that keep our velocity relatively high.

- We do development work on feature branches and merge them into the trunk via pull requests.
- Feature branches and their associated pull requests should be small.
- Small pull requests make for quicker and easier code reviews.
- Quicker code reviews allow us to expect shorter delays before code is reviewed.
- (Throwing something out there for discussion:) It seems reasonable to expect all pull requests be reviewed within one work day of submission.

That last is perhaps contentious. We as a team will need to try things out and iterate on our expectations for code review. 
## Releases
A release is built from and corresponds 1:1 with a tagged commit. A release could be as simple as making an ordinary commit to the trunk that updates the application versions from `-SNAPSHOT` or `.betaX` or whatever to a proper release version, and tagging that commit with some identifier.

We may instead choose to cut release branches from the trunk and release the code from these branches. The branch should be cut as late as possible, so that any changes that accumulate in the trunk can be released as soon as they are ready. It is important that development work not happen directly on or be merged directly to a release branch. If it is necessary to make changes and fix bugs found on a release branch, those fixes should be merged to the trunk and the commits cherry-picked to the release branch. 

The choice to release from the trunk or a branch could potentially be driven by operational concerns; for instance, we may run longer and more in-depth test suites on commits to release branches than we do on commits to the trunk. However, if we routinely find bugs using the in-depth testing on a release branch that we didn't find using the testing on the trunk, that is a sign that the testing on the trunk is inadequate.
## Merge Conflict Resolution
If my feature branch has a merge conflict with the trunk, how do I resolve it? There are two general strategies:
1. Merge the trunk into the feature branch. You can then resolve the merge conflict in a merge commit on the feature branch.
2. Rebase the feature branch onto the trunk. The commits on the feature branch are applied one-by-one onto the trunk, and you to fix any merge conflicts in each individual commit where a conflict occurs. This rewrites history, producing a "clean" feature branch which seems as if no merge conflict ever happened.

It is the opinion of the author that option 2 is preferable to option 1. Rewriting history on a shared branch is fraught with peril, true, but on a branch that only a single person works on it is fine. The resulting clean commit history is worth the additional risk.
## Feature Flags
The Trunk-Based Development philosophy is that work is merged into the trunk as quickly and frequently as possible, so long as the trunk is never broken. But some features cannot be finished on that kind of timescale. How can we merge an unfinished in-development feature into the trunk without leaving the trunk in a broken state?

The answer is what are called "feature flags". This is a mechanism by which we structure the code for a feature to change its behavior based on some configuration property. When we start developing a new feature, we create a new property and set its value such that the feature is avoided or skipped; maybe it has no external API, or maybe it has some stubbed out no-op behavior. That gets merged into the trunk. Development on the feature can proceed as usual, incrementally merging improvements into the trunk. During this whole time the feature can be tested by setting the appropriate config value; we should be writing tests as the feature is developed and running automated tests for both/all config values. Once development of the feature is complete it can go through QA as needed. When it has passed QA the default value of the feature flag can be changed so that the new feature is enabled by default. The scaffolding around the new feature—the config value and the previous default implementation—can be removed if they are no longer necessary.

What does this scaffolding look like in practice? Let's take the example of a Java application with Spring. We can set a property in the application's `application.yml` config file at deploy time containing our feature flag value. Spring will pick up that property and can autowire it wherever it needs to go. Using that property could be as simple as a conditional check
```java
if (myFeatureFlag) {
	newBehavior();
} else {
	noopBehavior();
}
```
But it would be a nicer and cleaner to lean on abstraction and dependency injection. Let's say you implement your feature in a service; you will have an interface in front of it and can have the default implementation of that interface do nothing. You can use the value of your feature flag to determine which service implementation Spring will autowire. For instance, you could store the service class name in the configuration value and use that value to load a class instance.
```java
bootContainer.addComponent(classFromName(config.get("myFeatureFlagName")));
```

Assumptions:
- We can accomplish all our development goals using feature flags that are set at boot time from a configuration file, environment variable, command-line arg, or similar. We do not need to change flag values (and application behavior) at runtime through an API or based on a value in a database.
- We will only ever have a small number of feature flags in the application at any given time—say fewer than 5—and they will only exist for a short time—say less than a few months. The more we have and the longer they last the more burden they will put on our automated testing, since we need to test all combinations of feature flag values.

For more, see [Trunk Based Development: Feature Flags](https://trunkbaseddevelopment.com/feature-flags/) and [Feature Toggle | Wikipedia](https://en.wikipedia.org/wiki/Feature_toggle).
