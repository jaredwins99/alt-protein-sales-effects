# Citation audit — main text

Working document. Pass 1 = main text (this file). Pass 2 = supplement.

Verdicts:

| tag | meaning |
|---|---|
| **NEEDS** | uncited claim about the external world or about methods; a reader/referee would expect a source |
| **SHOULD** | defensible uncited, but a citation would materially strengthen it or pre-empt a referee |
| **CHECK** | may already be cited in the supplement or may be a mis-attribution — verify before acting |
| **OK** | correctly uncited (own results, own definitions, arithmetic) |

Caveat: audited from the manuscript text alone. The `.tex` sources and `.bib`
are not in this repo, so nothing here is cross-checked against the supplement or
against whether a bib key exists.

---

## Headline

The statistics are the **best**-cited part of the paper. Every headline number —
FAOSTAT consumption, OECD/FAO projection, GFI investment, IPCC, IARC,
EAT-Lancet, all the taste-test and price-elasticity findings — carries a source.

The gaps cluster in three places instead:

1. **Software and methods citations** — Stan, ITS, regularization/shrinkage, the
   count-time-series model family. These are the most likely to be flagged in
   review and the easiest to fix.
2. **Auxiliary data sources** — weather and the inflation index are described but
   not sourced.
3. **Characterizations of a literature** — sentences that summarize what "most
   studies" or "advocates" do or claim, where the citation given supports a
   narrower point than the sentence makes.

---

## Introduction

| # | Location / claim | Verdict | Note |
|---|---|---|---|
| 1 | "neither these pronouncements nor **individual-focused persuasion efforts** have prevented the continued rise of meat consumption" | **NEEDS** | An empirical claim that persuasion interventions have not worked. There is a meta-analytic literature on exactly this; leaving it bare invites "according to whom?". Strongest single fix in the intro. |
| 2 | "Closing this gap … likely requires **structural interventions**: regulatory and fiscal policy…, institutional procurement…, choice architecture…, social marketing campaigns…, and market-side product development" | **NEEDS** | A five-part taxonomy of what works, entirely uncited. Each element has its own literature. At minimum one review covering the intervention landscape. |
| 3 | "Advocates … claim that customers will replace the majority of their meat purchases … provided they match meat in taste, price, and convenience" `\autocite{peacock2025price}` | **CHECK** | Attribution direction. `peacock2025price` appears later as a *critique* / reanalysis. Citing a sceptical source for what advocates believe is awkward — a primary advocacy source (industry/institute) alongside it would be cleaner. |
| 4 | "coincides with the **2016** popularization of flagship brands such as Beyond Meat and Impossible Foods" | **NEEDS** | Specific date + specific companies, uncited. Needs a market/industry or company source. |
| 5 | "**most products on the market** lack the meaty taste and texture desired by consumers, though the best performers are at or near taste-parity" | **SHOULD** | The sentences that follow cite three specific studies, but "most products on the market" is a population-level claim those studies don't establish. Either cite a broad sensory review or soften to "products vary widely, and many…". |
| 6 | "**Few studies** have specifically investigated the effects of alternative proteins on meat purchasing, instead testing meat-free interventions whose food-composition has either been unreported or … consisted entirely of whole foods … and first-generation meat substitutes" | **NEEDS** | This characterizes an entire literature and is load-bearing for the novelty claim. Two examples follow, but they are examples, not evidence about the field. Cite a systematic review, or state the scope of a search. |
| 7 | "the typical study venues (cafeterias) differ from other food-service settings on multiple dimensions that may affect generalizability: menu sets…, pricing structure…, occasion framing…, social context" | **SHOULD** | Plausible and clearly argued, but each dimension is asserted to matter for behaviour. One citation on setting effects would carry it. |
| 8 | "The study and full analysis plan were **preregistered**." | **SHOULD** | The OSF URL appears only in Methods. Convention is to give it (or a DOI) at first mention. |
| 9 | "we employed **modern causal inference methods** to address confounding" | **SHOULD** | Vague as written; the specifics that follow are the substance. Either cite or drop the framing sentence. |
| 10 | "using **regularization** for covariate shrinkage and selection" | **NEEDS** | A specific methodological choice (the supplement presumably names the prior). Needs the method citation in main text. |
| 11 | "treated each new introduction as a quasi-experiment, using an **interrupted time series (ITS)** specification for additional robustness to unmeasured confounding" | **NEEDS** | ITS is a named design with a standard methods literature. Currently uncited anywhere in the main text. High-visibility omission given ITS carries the causal claim. |

---

## Results

Almost entirely own findings and correctly uncited.

| # | Location / claim | Verdict | Note |
|---|---|---|---|
| 12 | "one to two false positives are expected by chance from 30 tests at $\alpha=.05$" | **OK** | Arithmetic. |
| 13 | "purchase volumes in 6 of the 7 restaurants were **sufficiently high to indicate** that the alternative proteins reached and were sampled by a meaningful share of customers" | **SHOULD** | Not a citation gap so much as an unstated threshold — "sufficiently high" and "meaningful share" are doing real work in defusing a null-result objection. Either give the criterion or point to the table. |
| 14 | Taste-test subset rationale `\autocite{Bedem2026}` | **OK** | Cited. |

---

## Discussion

| # | Location / claim | Verdict | Note |
|---|---|---|---|
| 15 | "**Cultivated meat**, meaning animal muscle assembled from cells cultured outside a live animal, **may better match sensory experience** of eating meat, though such products are **in their infancy** and face **distinct consumer-acceptance barriers**." | **NEEDS** | Three separable empirical claims, none cited. Consumer acceptance of cultivated meat in particular has a substantial literature. |
| 16 | "Social and psychological contributors may include **familiarity, identity, social norms, and responses to advertising**" | **SHOULD** | The `onwezen2024metareview` cite in the next sentence covers the *landscape* but is introduced as identifying what is *most-studied* — it doesn't underwrite this specific list. Either move it up or cite the individual constructs. |
| 17 | "several of our restaurants promoted newly introduced alternative proteins on social media" | **OK / CHECK** | Own observation from menu reconstruction — but if it came from the Instagram/Facebook sourcing described in Methods, say so, since it is otherwise an unsourced factual assertion about third parties. |
| 18 | Price premium `$1–2.5`, elasticities `\autocite{jahn2024substitution}` | **OK** | Own data + cited. |

---

## Methods

This is where the density of missing citations is highest.

| # | Location / claim | Verdict | Note |
|---|---|---|---|
| 19 | "All models were constructed and fit in the **Stan** programming language." | **NEEDS** | Software citation. Stan asks to be cited and most journals require it. |
| 20 | "we designed a **custom multilevel count time series model**" … "afforded **overdispersion** and handled closures through **zero truncation**" | **NEEDS** | The model family (count time series / INGARCH-type, negative-binomial observation) has an established literature. A custom model still cites its lineage. |
| 21 | "chosen models often exhibit a **winner's curse** and do not accurately reflect uncertainty" / "post-selection bias" | **NEEDS** | Named statistical phenomena presented as established fact, and used to justify a central design decision (superset model over cross-validated selection). |
| 22 | "**Weather**, including temperature and precipitation, was measured from local weather stations" | **NEEDS** | Data-source citation (which network/product). |
| 23 | "Inflation was tracked using the **food away from home index**" | **NEEDS** | Data-source citation (the BLS series). |
| 24 | "coded by **flagship LLMs**" / "We selected the LLM with the highest labeling accuracy" | **NEEDS** | Models must be named with version and date for reproducibility. May be in the supplement — verify — but a main-text pointer is expected. |
| 25 | "**Bonferroni** correction" `\autocite{vanderweele2019some}` | **OK** | Cited. |
| 26 | "CIs are the Bayesian counterpart to confidence intervals" | **OK** | Definitional. |
| 27 | "rolling **single-step forecasts**"; train/test split at 95% by time | **OK** | Own procedure; supplement carries detail. |
| 28 | "we confirmed that the models recovered known effects in **realistic simulations**" | **OK** | Own validation. |

---

## Not a citation issue, but caught in this pass

**Pairing counts do not reconcile.** The intro says **34 primary** outcome-exposure
pairings and, separately, **21 secondary** pairings — which sums to 55. Methods
says "over all analysis sets A1–A4, there were a total of **48** outcome-exposure
pairings". The abstract uses **48**. Either the 34/21 split or the 48 total is
wrong, or the categories overlap in a way the text does not explain. Worth
resolving before submission since three different numbers are visible to a
reader.

---

## Suggested order of work

1. **Methods block (19–24)** — mechanical, uncontroversial, and the most likely
   to be caught in review. Do these first.
2. **ITS + regularization (10, 11)** — these carry the causal and inferential
   claims; cheap to fix, high value.
3. **Literature characterizations (1, 2, 6)** — need real sourcing decisions, not
   just a key. Budget actual reading time.
4. **CHECK items (3, 24)** — verify attribution/location before changing anything.
5. Everything tagged **SHOULD** — a judgement call per item.
