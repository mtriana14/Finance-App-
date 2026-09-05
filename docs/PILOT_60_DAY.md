# 60-Day Merchant Pilot Plan

> **Status: working plan, not approved policy.** This is the pre-funding
> experiment — 20 merchants, 60 days of usage, $200 financing repaid over
> ~60 days. It is *not* the product described in `design-spec.md`, whose
> $300–$800 / 90-day loan terms and 10-merchant first ship describe where
> the product ends up, not this experiment. Where the two disagree on
> numbers, they are describing different stages, not contradicting
> each other.
>
> The financing leg depends on an unresolved legal question — whether
> Libreta may originate it directly or needs an authorized lending partner
> (`DECISIONS.md` §45, §46). Nothing in the merchant-facing messaging
> below may be published before counsel answers it.

### **Objective**

Run a controlled pilot with **20 small merchants in Ecuador who have an active RUC** to test whether Libreta can create consistent daily usage, capture meaningful business activity, and produce enough behavioral data to support a future small-credit product.

The pilot is not meant to prove the final underwriting model yet. Its first purpose is to prove that merchants will actually use Libreta consistently enough for the data to become useful.

### **Pilot structure**

Recruit **20 merchants** who fit Libreta’s target profile, such as small tiendas, market stalls, food vendors, salons, repair shops, carts, or other microbusinesses.

Each merchant receives the Libreta app and agrees to use it for **60 consecutive days**.

During that period, they are asked to record their real daily business activity, including things like:

* cash sales
* fiado transactions
* fiado repayments
* other business transactions Libreta supports
* regular use of the customer ledger

The pilot should emphasize **consistent real usage**, not artificially high revenue.

A merchant earning $20 per day and a merchant earning $100 per day are both useful to the experiment if they use the app honestly and consistently.

---

## **The $200 incentive**

The proposed incentive is:

> A merchant who completes the 60-day pilot according to the participation requirements becomes eligible to receive **$200 in financing**, repayable over approximately **60 days**.

The important distinction is that this should currently be treated as a **pilot hypothesis**, not as an unconditional public promise until the legal structure is confirmed.

You do not yet want Libreta publicly saying:

> “Use the app for 60 days and Libreta guarantees you a loan.”

because whether Libreta itself can legally originate or promise that financing in Ecuador still needs to be established.

The desired economic experience, however, is:

Merchant joins pilot
        ↓
Uses Libreta for 60 days
        ↓
Demonstrates consistent real usage
        ↓
Receives $200 financing
        ↓
Repays over 60 days
        ↓
Libreta observes repayment behavior

Ideally, the financing would be provided through whatever lawful structure is appropriate, potentially a licensed lending partner.

---

# **Why make the $200 amount the same for everyone?**

For this first pilot, the purpose isn't yet:

> “Can Libreta perfectly calculate how much this merchant should borrow?”

It is closer to:

> “Can we observe what happens when a diverse group of merchants uses Libreta consistently and then receives the same small financing amount?”

That gives you a cleaner experiment.

If one merchant averages:

$25/day

and another:

$90/day

you can later compare their behavior.

You begin learning whether variables such as:

* revenue consistency
* fiado repayment behavior
* transaction frequency
* business activity
* digital transaction volume later
* merchant engagement

appear related to repayment.

You don't want to assume the answer before collecting data.

---

# **Participation requirements**

I would not make the requirement literally:

> “Log something every single calendar day or lose the loan.”

That could encourage fake entries.

Instead, define **legitimate participation requirements**.

For example:

### **Merchant must:**

* have a valid RUC
* be operating a real business
* complete onboarding
* use Libreta as part of normal business activity
* record transactions honestly
* remain active throughout the 60-day period
* complete scheduled pilot check-ins
* not manufacture transactions simply to qualify
* consent to whatever pilot data collection is legally permitted

Then define completion based on something like:

active on ≥ X% of business days
+
minimum meaningful transaction activity
+
completed pilot check-ins
+
no obvious manipulation

The exact thresholds can be determined before recruitment.

That is better than rewarding someone for entering:

$1 cash sale

every night at 11:59 PM simply to preserve a streak.

---

# **What you measure during the first 60 days**

This is where the pilot becomes valuable.

### **Retention**

Your core metrics should include:

Day 1 activation
Day 7 retention
Day 14 retention
Day 30 retention
Day 45 retention
Day 60 completion

With 20 merchants, you can examine each merchant individually instead of hiding behavior inside aggregate percentages.

For example:

20 started

18 still using at Day 7

15 at Day 30

13 completed Day 60

That's already incredibly informative.

---

## **Usage**

Measure things such as:

* days active
* sessions or meaningful opens
* fiados created
* fiado payments recorded
* customers created
* cash transactions logged
* transactions per week
* average number of entries per active day
* number of weeks with consistent usage

You want to know:

> Is Libreta actually becoming part of the merchant's routine?

---

# **Qualitative merchant interviews**

With only 20 merchants, don't rely purely on analytics.

Talk to them.

I'd schedule brief check-ins around:

Day 0
Day 7
Day 30
Day 60

Ask things like:

* What made you open Libreta today?
* What do you still use paper for?
* What is annoying?
* Have you forgotten to log transactions?
* Why?
* Which screen do you use most?
* Would you continue using it without the $200 incentive?
* Would you recommend it to another merchant?
* What would make you stop using it?

The most important Day-60 question may actually be:

> **“If there were no $200 attached, would you continue using Libreta tomorrow?”**

Because otherwise you could accidentally prove only that people will use an app for free money.

---

# **Then comes the financing phase**

After the 60-day usage period, qualified pilot participants enter the financing portion.

Potential structure:

20 original merchants

↓ 60 days

qualified merchants

↓ financing

$200 each

↓ 60 days

repayment observation

If all 20 qualify, the maximum principal required is:

**20 × $200 \= $4,000.**

That's small enough that the experiment can potentially be structured without raising a large seed round first.

---

# **What happens during repayment**

You now have a second experiment:

### **Days 61–120**

Observe:

* on-time repayments
* missed payments
* partial repayments
* early repayments
* merchant communication
* business activity during repayment
* whether usage of Libreta continues
* whether pre-loan behavior appears associated with repayment

For example, eventually you might discover:

Merchant A
Average revenue: moderate
Very consistent logging
Stable fiado repayment
→ repaid perfectly

Merchant B
Higher revenue
Highly volatile activity
Heavy unpaid fiado
→ struggled to repay

That would be much more interesting than simply discovering that “higher revenue \= safer.”

---

# **An important experimental problem: the incentive itself**

There's one major issue you should explicitly recognize.

If merchants know:

> **“Use Libreta for 60 days and you get $200”**

then the $200 can substantially increase retention.

Therefore you haven't necessarily proven:

> “People love Libreta.”

You may have proven:

> “People will use Libreta for 60 days to get $200.”

That's still valuable — but it's a different conclusion.

So I would measure:

### **Incentivized retention**

during Days 1–60.

And then:

### **Post-incentive retention**

after the loan is issued.

If merchants continue using Libreta through Days 90, 120, etc., **that becomes much stronger evidence of actual product value.**

---

# **What success could look like**

Before starting, establish success criteria.

For example — these are illustrative, not magic thresholds:

20 merchants recruited

≥ 80% reach Day 7

≥ 65% reach Day 30

≥ 50–60% complete Day 60

Most active merchants log meaningful transactions weekly

Strong qualitative evidence that the fiado ledger solves
a recurring problem

Majority of completers continue using Libreta after financing begins

Repayment data is successfully collected for the first cohort

And importantly:

**Failure is useful too.**

If only 5 out of 20 merchants stay, you should know that **before raising $200,000 and building the lending infrastructure.**

---

# **Merchant messaging**

I would make the pitch simple.

Something along these lines:

> **Programa piloto Libreta — 60 días**

> Estamos seleccionando 20 pequeños negocios con RUC en Ecuador para probar Libreta.

> Durante 60 días usarás Libreta para registrar la actividad real de tu negocio y ayudarnos a entender cómo mejorar la aplicación para pequeños comerciantes.

> Los participantes que completen correctamente el programa y cumplan con sus condiciones podrán acceder a una financiación piloto de **$200**, sujeta a la estructura y condiciones del programa.

> No importa si tu negocio vende mucho o poco. Lo que queremos observar es el uso real y constante de Libreta.

I would **not yet publish that exact text** until the financing/legal language has been reviewed.

---

# **What the pilot actually proves**

Think of the pilot as answering four questions sequentially:

QUESTION 1
Can we recruit the right merchants?

        ↓

QUESTION 2
Will they actually use Libreta for 60 days?

        ↓

QUESTION 3
What does their business behavior look like?

        ↓

QUESTION 4
After receiving the same small financing amount,
what does repayment behavior look like?

Then later comes the much harder question:

QUESTION 5

Can historical Libreta behavior predict
future repayment sufficiently well to build
a responsible credit product?

Your first 20 merchants **will not prove Question 5 statistically**.

But they can give you the first real evidence that the entire chain is worth pursuing.

And that's why I think this is a much more meaningful pre-investor milestone than simply getting app downloads.
