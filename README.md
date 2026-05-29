# Surge Return

Customized Surge rules for overseas users who need optimized routing for China Mainland services and selected global services.

This project is based on the excellent work of [Sukka Ruleset](https://github.com/SukkaW/Surge).

## Features

- China Mainland services → Return Proxy
- Global services → Direct
- Selected services, such as GitHub and AI platforms → Proxy
- Advertising and tracking domains → Blocked

## Routing Strategy

| Traffic Type | Route |
| --- | --- |
| China Mainland Services | Return Proxy |
| Global Services | Direct |
| GitHub / AI Services | Proxy |
| Ads & Trackers | Block |

## Custom Rules

Custom rule sets are maintained under:

```text
List/overseas_return/
```

## Upstream Documentation

For detailed rule-set documentation, implementation details, and upstream rule descriptions, please refer to:

https://github.com/SukkaW/Surge

## Credits

This project is based on [Sukka Ruleset](https://github.com/SukkaW/Surge), created and maintained by [SukkaW](https://github.com/SukkaW) and contributors.

Special thanks to SukkaW for the original rule sets and ongoing maintenance.

## License

This project follows the licensing terms of the upstream project.

The upstream project is licensed under AGPL-3.0, except `List/ip/china_ip.conf`, which is licensed under CC BY-SA 2.0.

Please refer to the LICENSE file and the upstream repository for details:

https://github.com/SukkaW/Surge